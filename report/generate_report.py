from pathlib import Path

from reportlab.lib.colors import Color, HexColor
from reportlab.lib.enums import TA_CENTER
from reportlab.lib.pagesizes import A4, landscape
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.pdfgen import canvas
from reportlab.lib.utils import ImageReader


ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "preview" / "assets"
OUTPUT = ROOT / "output" / "pdf" / "潮汐之后-逐镜拉片报告.pdf"
PAGE_W, PAGE_H = landscape(A4)

BG = HexColor("#0d0e17")
PANEL = HexColor("#141620")
LINE = HexColor("#292b38")
WHITE = HexColor("#f4f4f8")
TEXT = HexColor("#c8c9d3")
MUTED = HexColor("#858899")
BLUE = HexColor("#7dbfff")
VIOLET = HexColor("#9a82ff")

FONT = "STHeiti"
pdfmetrics.registerFont(
    TTFont(FONT, "/System/Library/Fonts/STHeiti Medium.ttc", subfontIndex=0)
)


def wrap_text(text, font, size, max_width):
    lines = []
    current = ""
    for char in text:
        candidate = current + char
        if pdfmetrics.stringWidth(candidate, font, size) <= max_width:
            current = candidate
        else:
            if current:
                lines.append(current)
            current = char
    if current:
        lines.append(current)
    return lines


def draw_wrapped(c, text, x, y, width, size=8, leading=12, color=TEXT, max_lines=None):
    c.setFont(FONT, size)
    c.setFillColor(color)
    lines = wrap_text(text, FONT, size, width)
    if max_lines:
        lines = lines[:max_lines]
    for index, line in enumerate(lines):
        c.drawString(x, y - index * leading, line)
    return y - len(lines) * leading


def draw_cropped_image(c, path, x, y, width, height, radius=5, dim=0):
    image = ImageReader(str(path))
    source_w, source_h = image.getSize()
    scale = max(width / source_w, height / source_h)
    draw_w = source_w * scale
    draw_h = source_h * scale
    draw_x = x + (width - draw_w) / 2
    draw_y = y + (height - draw_h) / 2

    c.saveState()
    clip = c.beginPath()
    clip.roundRect(x, y, width, height, radius)
    c.clipPath(clip, stroke=0, fill=0)
    c.drawImage(image, draw_x, draw_y, draw_w, draw_h, mask="auto")
    if dim:
        c.setFillColor(BG)
        c.setFillAlpha(dim)
        c.rect(x, y, width, height, stroke=0, fill=1)
        c.setFillAlpha(1)
    c.restoreState()


def draw_page_background(c):
    c.setFillColor(BG)
    c.rect(0, 0, PAGE_W, PAGE_H, stroke=0, fill=1)
    c.saveState()
    c.setFillColor(VIOLET)
    c.setFillAlpha(0.12)
    c.circle(PAGE_W - 70, PAGE_H + 25, 150, stroke=0, fill=1)
    c.setFillColor(HexColor("#2d93ff"))
    c.setFillAlpha(0.12)
    c.circle(90, -80, 150, stroke=0, fill=1)
    c.restoreState()


def draw_footer(c, title, page_number):
    c.setStrokeColor(LINE)
    c.setLineWidth(0.45)
    c.line(28, 22, PAGE_W - 28, 22)
    c.setFillColor(HexColor("#626575"))
    c.setFont(FONT, 6.5)
    c.drawString(28, 10, title)
    c.drawRightString(PAGE_W - 28, 10, f"{page_number:02d}")


def draw_label(c, text, x, y):
    c.setFillColor(MUTED)
    c.setFont(FONT, 7)
    c.drawString(x, y, text)


def cover_page(c):
    draw_page_background(c)
    image_x, image_y, image_w, image_h = 186, 300, 470, 250
    draw_cropped_image(c, ASSETS / "still-01.png", image_x, image_y, image_w, image_h, 8, 0.27)
    c.setFillColor(HexColor("#e5e5eb"))
    c.setFont(FONT, 9)
    c.drawCentredString(PAGE_W / 2, image_y + image_h - 18, "海风再次吹过之前")

    c.setFillColor(MUTED)
    c.setFont("Helvetica", 7.5)
    c.drawCentredString(PAGE_W / 2, 268, "SHOT-BY-SHOT ANALYSIS")
    c.setFillColor(WHITE)
    c.setFont(FONT, 26)
    c.drawCentredString(PAGE_W / 2, 228, "《潮汐之后》逐镜拉片报告")
    c.setFillColor(HexColor("#a8a9b7"))
    c.setFont("Helvetica-Oblique", 10.5)
    c.drawCentredString(PAGE_W / 2, 205, "After the Tide — Director's Shot Analysis")

    c.setStrokeColor(LINE)
    c.setLineWidth(0.6)
    c.line(150, 176, PAGE_W - 150, 176)
    c.line(150, 151, PAGE_W - 150, 151)
    c.setFillColor(TEXT)
    c.setFont(FONT, 8.2)
    c.drawCentredString(
        PAGE_W / 2,
        160,
        "全片 124 分钟 · 23 场景 · 约 418 镜 · 基于镜头、声音与人物调度的导演视角分析",
    )

    credits = [("导演", "林澈"), ("编剧", "林澈 / 周遥"), ("摄影", "许冬"), ("剪辑", "方恬"), ("声音", "赵屿")]
    total_width = 390
    start_x = (PAGE_W - total_width) / 2
    column_width = total_width / len(credits)
    for index, (role, name) in enumerate(credits):
        x = start_x + index * column_width + column_width / 2
        c.setFillColor(WHITE)
        c.setFont(FONT, 7.2)
        c.drawCentredString(x, 120, role)
        c.setFillColor(MUTED)
        c.setFont(FONT, 7.2)
        c.drawCentredString(x, 104, name)

    draw_footer(c, "新天堂电影院·导演工作台", 1)
    c.showPage()


def overview_page(c):
    draw_page_background(c)
    draw_label(c, "DIRECTOR'S OVERVIEW", 34, PAGE_H - 38)
    c.setFillColor(WHITE)
    c.setFont(FONT, 23)
    c.drawString(34, PAGE_H - 69, "影片分析总览")
    c.setFillColor(HexColor("#666a7d"))
    c.setFont("Helvetica", 7)
    c.drawRightString(PAGE_W - 34, PAGE_H - 55, "02 / 04")

    left_x, top_y = 34, PAGE_H - 96
    main_w, card_h, gap = 385, 112, 9
    c.setFillColor(PANEL)
    c.setStrokeColor(LINE)
    c.roundRect(left_x, top_y - card_h, main_w, card_h, 8, stroke=1, fill=1)
    draw_label(c, "核心判断", left_x + 15, top_y - 19)
    draw_wrapped(
        c,
        "影片用“未完成的对话”推动人物关系，而不是依靠情节反转。",
        left_x + 15,
        top_y - 43,
        main_w - 30,
        size=12,
        leading=17,
        color=WHITE,
        max_lines=2,
    )
    draw_wrapped(
        c,
        "镜头经常停留在人物开口之前或离开之后。空镜、环境声和画面边缘的人物动作，共同承担了没有说出口的内容。",
        left_x + 15,
        top_y - 83,
        main_w - 30,
        size=7.3,
        leading=10.5,
        color=MUTED,
        max_lines=2,
    )

    metrics = [("7.4 秒", "平均镜头时长"), ("31%", "固定机位占比"), ("18 次", "海浪声重复出现")]
    metric_x = left_x + main_w + gap
    metric_w = (PAGE_W - 34 - metric_x - gap * 2) / 3
    for index, (value, label) in enumerate(metrics):
        x = metric_x + index * (metric_w + gap)
        c.setFillColor(PANEL)
        c.setStrokeColor(LINE)
        c.roundRect(x, top_y - card_h, metric_w, card_h, 8, stroke=1, fill=1)
        c.setFillColor(WHITE)
        c.setFont(FONT, 18)
        c.drawString(x + 13, top_y - 55, value)
        c.setFillColor(MUTED)
        c.setFont(FONT, 7)
        c.drawString(x + 13, top_y - 75, label)

    sections = [
        ("视觉策略", "距离先于表情", "全景和中远景先建立人物之间的空间关系，近景只在关系发生细微改变时出现，因此每次靠近都会显得更有重量。"),
        ("节奏策略", "停顿构成第二条叙事线", "剪辑保留动作完成后的两到三秒，让环境声继续存在。观众不是被带往下一条信息，而是被留在人物的犹豫里。"),
        ("声音策略", "海浪声连接不同时空", "海浪并不总与海面同时出现。它被用作人物记忆的入口，在现实场景中提前进入，又在回忆结束后延迟退出。"),
    ]
    section_y = top_y - card_h - 12
    section_w = (PAGE_W - 68 - gap * 2) / 3
    section_h = 105
    for index, (label, title, body) in enumerate(sections):
        x = 34 + index * (section_w + gap)
        c.setFillColor(PANEL)
        c.setStrokeColor(LINE)
        c.roundRect(x, section_y - section_h, section_w, section_h, 8, stroke=1, fill=1)
        draw_label(c, label, x + 14, section_y - 19)
        c.setFillColor(WHITE)
        c.setFont(FONT, 10)
        c.drawString(x + 14, section_y - 40, title)
        draw_wrapped(c, body, x + 14, section_y - 59, section_w - 28, 7.2, 10.5, MUTED, 4)

    frame_y, frame_h, frame_gap = 55, 176, 8
    frame_w = (PAGE_W - 68 - frame_gap * 3) / 4
    frames = [
        ("still-02.png", "人物被门框切分"),
        ("still-04.png", "空桌保留关系余温"),
        ("still-07.png", "前景遮挡制造迟疑"),
        ("still-10.png", "海面成为情绪出口"),
    ]
    for index, (filename, caption) in enumerate(frames):
        x = 34 + index * (frame_w + frame_gap)
        draw_cropped_image(c, ASSETS / filename, x, frame_y, frame_w, frame_h, 6, 0.12)
        c.saveState()
        c.setFillColor(BG)
        c.setFillAlpha(0.78)
        c.rect(x, frame_y, frame_w, 25, stroke=0, fill=1)
        c.restoreState()
        c.setFillColor(TEXT)
        c.setFont(FONT, 7)
        c.drawString(x + 9, frame_y + 9, caption)

    draw_footer(c, "《潮汐之后》逐镜拉片报告", 2)
    c.showPage()


SCENES = [
    (
        "SCENE 12 · 00:42:06—00:42:27",
        "场景十二：雨夜咖啡馆重逢",
        [
            ("still-03.png", "镜 085", "42:06:00\n—42:10:06", "全景", "固定", "雨夜街道与咖啡馆外立面。人物尚未出现，玻璃上的倒影先进入画面。", "雨声、远处车流，室内音乐被玻璃削弱。", "先建立情绪，再让人物入场。倒影把“重逢”处理成记忆先于现实抵达。"),
            ("still-05.png", "镜 086", "42:10:06\n—42:16:04", "中远景", "缓慢跟随", "女主推门进入，停在门口寻找座位。镜头只移动半个身位，没有追到她的正面。", "门铃、脚步、椅子摩擦声，音乐变清晰。", "克制的跟随保留陌生感。观众与人物保持半步距离，没有立刻获得她的情绪答案。"),
            ("still-06.png", "镜 087", "42:16:04\n—42:24:08", "中景", "固定", "两人隔桌而坐，人物分处画面两端。服务员从中间经过，短暂遮住彼此。", "对白很轻，咖啡机蒸汽声两次盖过句尾。", "横向距离就是关系距离。遮挡和噪声让这次对话始终无法真正抵达对方。"),
            ("still-08.png", "镜 088", "42:24:08\n—42:27:18", "俯拍近景", "固定", "两只咖啡杯与桌下收紧的手。人物没有说话，勺子在杯沿停住。", "勺子轻碰杯沿，雨声短暂变大。", "把表演转移到物件和手部。俯拍压低情绪，让未说出口的话变得可见。"),
        ],
    ),
    (
        "SCENE 13 · 00:42:27—00:42:52",
        "场景十三：一句话之后的沉默",
        [
            ("still-09.png", "镜 089", "42:27:18\n—42:33:02", "特写", "固定", "女主第一次直视对方。眼睛处于焦点，脸部其余部分逐渐落入阴影。", "对白停止，只剩冰箱低频与呼吸。", "全场第一次特写就是关系转折。不是强调台词，而是强调她决定不再解释。"),
            ("still-10.png", "镜 090", "42:33:02\n—42:39:10", "近景", "缓慢推近", "男主没有回应，视线越过女主看向窗外。背景中的海面逐渐变成虚焦亮斑。", "远处海浪声提前进入，室内环境声减弱。", "推近身体，却让意识离开现场。声画方向相反，把人物带入过去的记忆。"),
            ("still-11.png", "镜 091", "42:39:10\n—42:44:06", "中景", "横移", "服务员从前景经过，镜头随他横移，重新露出两人时，女主已经起身。", "脚步、餐具碰撞，海浪声持续。", "用日常动作完成时间跳跃。遮挡省略了起身过程，让离开显得更突然、更坚决。"),
            ("still-12.png", "镜 092", "42:44:06\n—42:52:12", "全景", "固定", "女主离开画面，男主仍坐在原位。空椅占据画面中心，镜头停留八秒。", "门铃后恢复雨声，海浪声延迟两秒退出。", "让空位成为最后的角色。长停顿拒绝立即进入下一场，迫使观众承担余波。"),
        ],
    ),
]


def table_page(c, scene_label, scene_title, rows, page_number):
    draw_page_background(c)
    draw_label(c, scene_label, 28, PAGE_H - 35)
    c.setFillColor(WHITE)
    c.setFont(FONT, 18)
    c.drawString(28, PAGE_H - 61, scene_title)
    c.setFillColor(HexColor("#666a7d"))
    c.setFont("Helvetica", 7)
    c.drawRightString(PAGE_W - 28, PAGE_H - 47, f"{page_number:02d} / 04")

    table_x = 28
    table_top = PAGE_H - 82
    widths = [132, 45, 64, 40, 53, 135, 94, 223]
    headers = ["截图", "镜号", "时间码", "景别", "镜头运动", "画面内容 / 人物动作", "声音 / 音乐", "导演分析"]
    head_h = 24
    row_h = 109

    c.setFillColor(HexColor("#151827"))
    c.setStrokeColor(LINE)
    c.roundRect(table_x, table_top - head_h - row_h * 4, sum(widths), head_h + row_h * 4, 6, stroke=1, fill=1)

    x = table_x
    for width, header in zip(widths, headers):
        c.setFillColor(HexColor("#8388a0"))
        c.setFont(FONT, 6.5)
        c.drawString(x + 7, table_top - 16, header)
        x += width

    y = table_top - head_h
    for row_index, row in enumerate(rows):
        c.setStrokeColor(LINE)
        c.setLineWidth(0.45)
        c.line(table_x, y, table_x + sum(widths), y)
        x = table_x
        for width in widths[:-1]:
            x += width
            c.line(x, table_top, x, table_top - head_h - row_h * 4)

        image, shot, timecode, size, movement, action, sound, analysis = row
        image_x = table_x + 5
        image_y = y - row_h + 5
        draw_cropped_image(c, ASSETS / image, image_x, image_y, widths[0] - 10, row_h - 10, 4, 0.05)

        x = table_x + widths[0]
        c.setFillColor(BLUE)
        c.setFont(FONT, 7)
        c.drawString(x + 7, y - 19, shot)

        x += widths[1]
        c.setFillColor(TEXT)
        c.setFont("Helvetica", 6.5)
        for index, line in enumerate(timecode.split("\n")):
            c.drawString(x + 6, y - 18 - index * 10, line)

        x += widths[2]
        draw_wrapped(c, size, x + 6, y - 18, widths[3] - 12, 6.7, 9, TEXT, 3)
        x += widths[3]
        draw_wrapped(c, movement, x + 6, y - 18, widths[4] - 12, 6.7, 9, TEXT, 4)
        x += widths[4]
        draw_wrapped(c, action, x + 6, y - 18, widths[5] - 12, 6.7, 9.3, TEXT, 9)
        x += widths[5]
        draw_wrapped(c, sound, x + 6, y - 18, widths[6] - 12, 6.5, 9.3, MUTED, 9)
        x += widths[6]
        draw_wrapped(c, analysis, x + 7, y - 18, widths[7] - 14, 6.8, 9.5, WHITE, 9)
        y -= row_h

    draw_footer(c, "《潮汐之后》逐镜拉片报告", page_number)
    c.showPage()


def build_pdf():
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    c = canvas.Canvas(str(OUTPUT), pagesize=(PAGE_W, PAGE_H))
    c.setTitle("《潮汐之后》逐镜拉片报告")
    c.setAuthor("新天堂电影院·导演工作台")
    cover_page(c)
    overview_page(c)
    for page_number, scene in enumerate(SCENES, start=3):
        table_page(c, scene[0], scene[1], scene[2], page_number)
    c.save()
    print(OUTPUT)


if __name__ == "__main__":
    build_pdf()
