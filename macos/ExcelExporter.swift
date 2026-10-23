import AppKit
import Foundation

enum CinemaExcelExporterError: Error {
    case invalidReport
    case destinationExists
    case zipFailed
}

enum CinemaExcelExporter {
    private struct Shot {
        let number: Int
        let start: Double
        let end: Double
        let size: String
        let angle: String
        let movement: String
        let action: String
        let dialogue: String
        let note: String
        let imageURL: String
    }

    private struct ImageAsset {
        let fileName: String
        let extensionName: String
        let data: Data
        let rowIndex: Int
        let width: Double
        let height: Double
        let offsetX: Double
        let offsetY: Double
    }

    static func safeFileName(_ value: String) -> String {
        let invalid = CharacterSet(charactersIn: "/:\\?%*|\"<>")
        let cleaned = value.components(separatedBy: invalid).joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "未命名影片" : cleaned
    }

    static func export(
        report: [String: Any],
        destinationURL: URL,
        replaceExisting: Bool
    ) throws {
        guard
            let project = report["project"] as? [String: Any],
            let projectName = project["name"] as? String,
            let shotValues = report["shots"] as? [[String: Any]]
        else {
            throw CinemaExcelExporterError.invalidReport
        }

        let shots = shotValues.enumerated().map { index, value in
            Shot(
                number: integer(value["number"]) ?? index + 1,
                start: decimal(value["start"]) ?? 0,
                end: decimal(value["end"]) ?? 0,
                size: text(value["size"]),
                angle: text(value["angle"]),
                movement: text(value["movement"]),
                action: text(value["action"]),
                dialogue: text(value["dialogueText"]),
                note: text(value["note"]),
                imageURL: text(value["imageUrl"])
            )
        }

        if FileManager.default.fileExists(atPath: destinationURL.path) {
            guard replaceExisting else {
                throw CinemaExcelExporterError.destinationExists
            }
            try FileManager.default.removeItem(at: destinationURL)
        }

        let packageURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("cinema-excel-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: packageURL, withIntermediateDirectories: true)

        let imageAssets = loadImages(from: shots)
        try writePackage(
            at: packageURL,
            projectName: projectName,
            duration: decimal(project["duration"]) ?? 0,
            generatedDate: text(report["generatedDate"]),
            shots: shots,
            imageAssets: imageAssets
        )
        try zipPackage(at: packageURL, destinationURL: destinationURL)
    }

    private static func writePackage(
        at packageURL: URL,
        projectName: String,
        duration: Double,
        generatedDate: String,
        shots: [Shot],
        imageAssets: [ImageAsset]
    ) throws {
        try writeXML(contentTypesXML(hasImages: !imageAssets.isEmpty), to: packageURL, path: "[Content_Types].xml")
        try writeXML(rootRelationshipsXML, to: packageURL, path: "_rels/.rels")
        try writeXML(corePropertiesXML(projectName: projectName), to: packageURL, path: "docProps/core.xml")
        try writeXML(appPropertiesXML, to: packageURL, path: "docProps/app.xml")
        try writeXML(workbookXML, to: packageURL, path: "xl/workbook.xml")
        try writeXML(workbookRelationshipsXML, to: packageURL, path: "xl/_rels/workbook.xml.rels")
        try writeXML(stylesXML, to: packageURL, path: "xl/styles.xml")
        try writeXML(
            worksheetXML(
                projectName: projectName,
                duration: duration,
                generatedDate: generatedDate,
                shots: shots,
                hasImages: !imageAssets.isEmpty
            ),
            to: packageURL,
            path: "xl/worksheets/sheet1.xml"
        )

        guard !imageAssets.isEmpty else { return }
        try writeXML(sheetRelationshipsXML, to: packageURL, path: "xl/worksheets/_rels/sheet1.xml.rels")
        try writeXML(drawingXML(imageAssets), to: packageURL, path: "xl/drawings/drawing1.xml")
        try writeXML(
            drawingRelationshipsXML(imageAssets),
            to: packageURL,
            path: "xl/drawings/_rels/drawing1.xml.rels"
        )
        for asset in imageAssets {
            try writeData(asset.data, to: packageURL, path: "xl/media/\(asset.fileName)")
        }
    }

    private static func writeXML(_ value: String, to root: URL, path: String) throws {
        try writeData(Data(value.utf8), to: root, path: path)
    }

    private static func writeData(_ data: Data, to root: URL, path: String) throws {
        let url = root.appendingPathComponent(path)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: url, options: .atomic)
    }

    private static func zipPackage(at packageURL: URL, destinationURL: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.arguments = ["-qr", destinationURL.path, "."]
        process.currentDirectoryURL = packageURL
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw CinemaExcelExporterError.zipFailed
        }
    }

    private static func loadImages(from shots: [Shot]) -> [ImageAsset] {
        var assets: [ImageAsset] = []
        for (index, shot) in shots.enumerated() {
            guard let data = imageData(from: shot.imageURL) else { continue }
            let extensionName = imageExtension(for: data)
            let size = NSImage(data: data)?.size ?? NSSize(width: 16, height: 9)
            let fitted = fittedImageSize(size)
            assets.append(
                ImageAsset(
                    fileName: "image\(assets.count + 1).\(extensionName)",
                    extensionName: extensionName,
                    data: data,
                    rowIndex: index + 4,
                    width: fitted.width,
                    height: fitted.height,
                    offsetX: 6 + ((160 - fitted.width) / 2),
                    offsetY: 4 + ((74 - fitted.height) / 2)
                )
            )
        }
        return assets
    }

    private static func imageData(from value: String) -> Data? {
        guard !value.isEmpty else { return nil }
        if value.hasPrefix("data:image"), let comma = value.firstIndex(of: ",") {
            return Data(base64Encoded: String(value[value.index(after: comma)...]))
        }
        guard let url = URL(string: value), url.isFileURL else { return nil }
        return try? Data(contentsOf: url)
    }

    private static func imageExtension(for data: Data) -> String {
        let bytes = [UInt8](data.prefix(8))
        if bytes.count >= 8, bytes == [137, 80, 78, 71, 13, 10, 26, 10] {
            return "png"
        }
        return "jpeg"
    }

    private static func fittedImageSize(_ size: NSSize) -> (width: Double, height: Double) {
        let safeWidth = max(1, Double(size.width))
        let safeHeight = max(1, Double(size.height))
        let scale = min(160 / safeWidth, 74 / safeHeight)
        return (safeWidth * scale, safeHeight * scale)
    }

    private static func worksheetXML(
        projectName: String,
        duration: Double,
        generatedDate: String,
        shots: [Shot],
        hasImages: Bool
    ) -> String {
        let lastRow = max(4, shots.count + 4)
        var rows = [
            rowXML(1, height: 34, cells: [cellXML("A1", "《\(projectName)》专业图文拉片表", style: 1)]),
            rowXML(2, height: 22, cells: [cellXML("A2", "新天堂电影院·导演工作台", style: 2)]),
            rowXML(
                3,
                height: 24,
                cells: [
                    cellXML(
                        "A3",
                        "全片 \(durationLabel(duration)) · \(shots.count) 镜 · 生成日期 \(generatedDate.isEmpty ? dateLabel() : generatedDate)",
                        style: 2
                    ),
                ]
            ),
            rowXML(
                4,
                height: 28,
                cells: zip(
                    ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J"],
                    ["静帧", "镜号", "入点", "出点", "景别", "机位", "运镜", "基础识别 / 画面内容", "字幕 / 对白", "导演笔记"]
                ).map { cellXML("\($0)4", $1, style: 3) }
            ),
        ]

        for (index, shot) in shots.enumerated() {
            let row = index + 5
            let alternatingStyle = index.isMultiple(of: 2) ? 4 : 5
            let noteStyle = index.isMultiple(of: 2) ? 6 : 7
            rows.append(
                rowXML(
                    row,
                    height: 96,
                    cells: [
                        cellXML("A\(row)", shot.imageURL.isEmpty ? "暂无代表静帧" : "", style: alternatingStyle),
                        cellXML("B\(row)", "镜 \(String(format: "%03d", shot.number))", style: alternatingStyle),
                        cellXML("C\(row)", timecode(shot.start), style: alternatingStyle),
                        cellXML("D\(row)", timecode(shot.end), style: alternatingStyle),
                        cellXML("E\(row)", shot.size.isEmpty ? "未填写" : shot.size, style: alternatingStyle),
                        cellXML("F\(row)", shot.angle.isEmpty ? "未填写" : shot.angle, style: alternatingStyle),
                        cellXML("G\(row)", shot.movement.isEmpty ? "未填写" : shot.movement, style: alternatingStyle),
                        cellXML("H\(row)", shot.action.isEmpty ? "尚未填写画面内容" : shot.action, style: noteStyle),
                        cellXML("I\(row)", shot.dialogue.isEmpty ? "当前镜头无字幕对白" : shot.dialogue, style: noteStyle),
                        cellXML("J\(row)", shot.note.isEmpty ? "尚未填写导演笔记" : shot.note, style: noteStyle),
                    ]
                )
            )
        }

        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
          <sheetPr><pageSetUpPr fitToPage="1"/></sheetPr>
          <dimension ref="A1:J\(lastRow)"/>
          <sheetViews>
            <sheetView showGridLines="0" workbookViewId="0">
              <pane ySplit="4" topLeftCell="A5" activePane="bottomLeft" state="frozen"/>
              <selection pane="bottomLeft" activeCell="B5" sqref="B5"/>
            </sheetView>
          </sheetViews>
          <sheetFormatPr defaultRowHeight="20"/>
          <cols>
            <col min="1" max="1" width="24" customWidth="1"/>
            <col min="2" max="2" width="11" customWidth="1"/>
            <col min="3" max="4" width="16" customWidth="1"/>
            <col min="5" max="7" width="12" customWidth="1"/>
            <col min="8" max="9" width="38" customWidth="1"/>
            <col min="10" max="10" width="48" customWidth="1"/>
          </cols>
          <sheetData>\(rows.joined())</sheetData>
          <mergeCells count="3"><mergeCell ref="A1:J1"/><mergeCell ref="A2:J2"/><mergeCell ref="A3:J3"/></mergeCells>
          <autoFilter ref="A4:J\(lastRow)"/>
          <printOptions horizontalCentered="0" verticalCentered="0"/>
          <pageMargins left="0.3" right="0.3" top="0.45" bottom="0.45" header="0.2" footer="0.2"/>
          <pageSetup paperSize="9" orientation="landscape" fitToWidth="1" fitToHeight="0"/>
          <headerFooter><oddFooter>&amp;L新天堂电影院·导演工作台&amp;R第 &amp;P / &amp;N 页</oddFooter></headerFooter>
          \(hasImages ? "<drawing r:id=\"rId1\"/>" : "")
        </worksheet>
        """
    }

    private static func rowXML(_ number: Int, height: Double, cells: [String]) -> String {
        "<row r=\"\(number)\" ht=\"\(height)\" customHeight=\"1\">\(cells.joined())</row>"
    }

    private static func cellXML(_ reference: String, _ value: String, style: Int) -> String {
        "<c r=\"\(reference)\" s=\"\(style)\" t=\"inlineStr\"><is><t xml:space=\"preserve\">\(xml(value))</t></is></c>"
    }

    private static func drawingXML(_ assets: [ImageAsset]) -> String {
        let anchors = assets.enumerated().map { index, asset in
            let pictureID = index + 1
            return """
            <xdr:oneCellAnchor>
              <xdr:from>
                <xdr:col>0</xdr:col><xdr:colOff>\(emu(asset.offsetX))</xdr:colOff>
                <xdr:row>\(asset.rowIndex)</xdr:row><xdr:rowOff>\(emu(asset.offsetY))</xdr:rowOff>
              </xdr:from>
              <xdr:ext cx="\(emu(asset.width))" cy="\(emu(asset.height))"/>
              <xdr:pic>
                <xdr:nvPicPr><xdr:cNvPr id="\(pictureID)" name="镜头静帧 \(pictureID)"/><xdr:cNvPicPr/></xdr:nvPicPr>
                <xdr:blipFill><a:blip r:embed="rId\(pictureID)"/><a:stretch><a:fillRect/></a:stretch></xdr:blipFill>
                <xdr:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="\(emu(asset.width))" cy="\(emu(asset.height))"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom><a:ln><a:solidFill><a:srgbClr val="CBD5E1"/></a:solidFill></a:ln></xdr:spPr>
              </xdr:pic>
              <xdr:clientData/>
            </xdr:oneCellAnchor>
            """
        }.joined()
        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <xdr:wsDr xmlns:xdr="http://schemas.openxmlformats.org/drawingml/2006/spreadsheetDrawing" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
          \(anchors)
        </xdr:wsDr>
        """
    }

    private static func drawingRelationshipsXML(_ assets: [ImageAsset]) -> String {
        let relationships = assets.enumerated().map { index, asset in
            "<Relationship Id=\"rId\(index + 1)\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/image\" Target=\"../media/\(asset.fileName)\"/>"
        }.joined()
        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">\(relationships)</Relationships>
        """
    }

    private static func contentTypesXML(hasImages: Bool) -> String {
        """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
          <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
          <Default Extension="xml" ContentType="application/xml"/>
          <Default Extension="png" ContentType="image/png"/>
          <Default Extension="jpeg" ContentType="image/jpeg"/>
          <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
          <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
          <Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>
          <Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>
          <Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>
          \(hasImages ? "<Override PartName=\"/xl/drawings/drawing1.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.drawing+xml\"/>" : "")
        </Types>
        """
    }

    private static let rootRelationshipsXML = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
      <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
      <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>
      <Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/>
    </Relationships>
    """

    private static let workbookXML = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
      <bookViews><workbookView xWindow="0" yWindow="0" windowWidth="24000" windowHeight="14000"/></bookViews>
      <sheets><sheet name="专业图文拉片表" sheetId="1" r:id="rId1"/></sheets>
      <calcPr calcId="191029"/>
    </workbook>
    """

    private static let workbookRelationshipsXML = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
      <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
      <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
    </Relationships>
    """

    private static let sheetRelationshipsXML = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
      <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/drawing" Target="../drawings/drawing1.xml"/>
    </Relationships>
    """

    private static let stylesXML = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
      <fonts count="5">
        <font><sz val="10"/><name val="PingFang SC"/><family val="2"/></font>
        <font><b/><sz val="20"/><color rgb="FFFFFFFF"/><name val="PingFang SC"/><family val="2"/></font>
        <font><sz val="10"/><color rgb="FF536579"/><name val="PingFang SC"/><family val="2"/></font>
        <font><b/><sz val="10"/><color rgb="FFFFFFFF"/><name val="PingFang SC"/><family val="2"/></font>
        <font><sz val="10"/><color rgb="FF243447"/><name val="PingFang SC"/><family val="2"/></font>
      </fonts>
      <fills count="6">
        <fill><patternFill patternType="none"/></fill>
        <fill><patternFill patternType="gray125"/></fill>
        <fill><patternFill patternType="solid"><fgColor rgb="FF17263C"/><bgColor indexed="64"/></patternFill></fill>
        <fill><patternFill patternType="solid"><fgColor rgb="FF315E8B"/><bgColor indexed="64"/></patternFill></fill>
        <fill><patternFill patternType="solid"><fgColor rgb="FFF8FAFD"/><bgColor indexed="64"/></patternFill></fill>
        <fill><patternFill patternType="solid"><fgColor rgb="FFEDF3F8"/><bgColor indexed="64"/></patternFill></fill>
      </fills>
      <borders count="2">
        <border><left/><right/><top/><bottom/><diagonal/></border>
        <border>
          <left style="thin"><color rgb="FFD6DEE8"/></left>
          <right style="thin"><color rgb="FFD6DEE8"/></right>
          <top style="thin"><color rgb="FFD6DEE8"/></top>
          <bottom style="thin"><color rgb="FFD6DEE8"/></bottom>
          <diagonal/>
        </border>
      </borders>
      <cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>
      <cellXfs count="8">
        <xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>
        <xf numFmtId="0" fontId="1" fillId="2" borderId="0" xfId="0" applyAlignment="1"><alignment horizontal="center" vertical="center"/></xf>
        <xf numFmtId="0" fontId="2" fillId="0" borderId="0" xfId="0" applyAlignment="1"><alignment horizontal="center" vertical="center"/></xf>
        <xf numFmtId="0" fontId="3" fillId="3" borderId="1" xfId="0" applyAlignment="1"><alignment horizontal="center" vertical="center" wrapText="1"/></xf>
        <xf numFmtId="0" fontId="4" fillId="4" borderId="1" xfId="0" applyAlignment="1"><alignment horizontal="center" vertical="center" wrapText="1"/></xf>
        <xf numFmtId="0" fontId="4" fillId="5" borderId="1" xfId="0" applyAlignment="1"><alignment horizontal="center" vertical="center" wrapText="1"/></xf>
        <xf numFmtId="0" fontId="4" fillId="4" borderId="1" xfId="0" applyAlignment="1"><alignment horizontal="left" vertical="center" wrapText="1"/></xf>
        <xf numFmtId="0" fontId="4" fillId="5" borderId="1" xfId="0" applyAlignment="1"><alignment horizontal="left" vertical="center" wrapText="1"/></xf>
      </cellXfs>
      <cellStyles count="1"><cellStyle name="常规" xfId="0" builtinId="0"/></cellStyles>
      <dxfs count="0"/>
      <tableStyles count="0" defaultTableStyle="TableStyleMedium2" defaultPivotStyle="PivotStyleLight16"/>
    </styleSheet>
    """

    private static func corePropertiesXML(projectName: String) -> String {
        """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcterms="http://purl.org/dc/terms/" xmlns:dcmitype="http://purl.org/dc/dcmitype/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
          <dc:title>\(xml(projectName))专业图文拉片表</dc:title>
          <dc:creator>新天堂电影院·导演工作台</dc:creator>
          <cp:lastModifiedBy>新天堂电影院·导演工作台</cp:lastModifiedBy>
          <dcterms:created xsi:type="dcterms:W3CDTF">\(ISO8601DateFormatter().string(from: Date()))</dcterms:created>
        </cp:coreProperties>
        """
    }

    private static let appPropertiesXML = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties" xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes">
      <Application>新天堂电影院·导演工作台</Application>
      <AppVersion>0.9.0</AppVersion>
    </Properties>
    """

    private static func text(_ value: Any?) -> String {
        value as? String ?? ""
    }

    private static func integer(_ value: Any?) -> Int? {
        if let number = value as? NSNumber { return number.intValue }
        return value as? Int
    }

    private static func decimal(_ value: Any?) -> Double? {
        if let number = value as? NSNumber { return number.doubleValue }
        return value as? Double
    }

    private static func timecode(_ totalSeconds: Double) -> String {
        let safeSeconds = max(0, totalSeconds)
        let hours = Int(safeSeconds / 3600)
        let minutes = Int(safeSeconds.truncatingRemainder(dividingBy: 3600) / 60)
        let seconds = Int(safeSeconds.truncatingRemainder(dividingBy: 60))
        let frames = min(24, Int(safeSeconds.truncatingRemainder(dividingBy: 1) * 25))
        return String(format: "%02d:%02d:%02d:%02d", hours, minutes, seconds, frames)
    }

    private static func durationLabel(_ totalSeconds: Double) -> String {
        let safeSeconds = max(0, totalSeconds)
        if safeSeconds >= 3600 {
            return "\(Int(safeSeconds / 3600)) 小时 \(Int(safeSeconds.truncatingRemainder(dividingBy: 3600) / 60)) 分钟"
        }
        if safeSeconds >= 60 {
            return "\(Int(safeSeconds / 60)) 分钟"
        }
        return String(format: "%.1f 秒", safeSeconds)
    }

    private static func dateLabel() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd"
        return formatter.string(from: Date())
    }

    private static func emu(_ pixels: Double) -> Int {
        Int((pixels * 9525).rounded())
    }

    private static func xml(_ value: String) -> String {
        let filtered = value.unicodeScalars.filter {
            $0.value == 9 || $0.value == 10 || $0.value == 13 || $0.value >= 32
        }
        return String(String.UnicodeScalarView(filtered))
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}
