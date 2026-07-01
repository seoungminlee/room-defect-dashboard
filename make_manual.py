from docx import Document
from docx.shared import Pt, RGBColor, Cm, Inches
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.table import WD_TABLE_ALIGNMENT, WD_ALIGN_VERTICAL
from docx.oxml.ns import qn
from docx.oxml import OxmlElement
import copy

doc = Document()

# ── 페이지 설정 (A4) ──────────────────────────────────────
section = doc.sections[0]
section.page_width  = Cm(21)
section.page_height = Cm(29.7)
section.left_margin   = Cm(2.5)
section.right_margin  = Cm(2.5)
section.top_margin    = Cm(2.5)
section.bottom_margin = Cm(2.5)

# ── 스타일 헬퍼 ──────────────────────────────────────────
BLUE   = RGBColor(0x25, 0x63, 0xEB)   # 브랜드 블루
DARK   = RGBColor(0x1C, 0x1F, 0x24)
GRAY   = RGBColor(0x6B, 0x72, 0x80)
LGRAY  = RGBColor(0xF3, 0xF4, 0xF6)
WHITE  = RGBColor(0xFF, 0xFF, 0xFF)
GREEN  = RGBColor(0x16, 0xA3, 0x4A)
AMBER  = RGBColor(0xD9, 0x77, 0x06)
RED    = RGBColor(0xDC, 0x26, 0x26)

def set_cell_bg(cell, hex_color):
    tc   = cell._tc
    tcPr = tc.get_or_add_tcPr()
    shd  = OxmlElement('w:shd')
    shd.set(qn('w:val'),   'clear')
    shd.set(qn('w:color'), 'auto')
    shd.set(qn('w:fill'),  hex_color)
    tcPr.append(shd)

def set_cell_border(cell, color='CCCCCC'):
    tc   = cell._tc
    tcPr = tc.get_or_add_tcPr()
    tcBorders = OxmlElement('w:tcBorders')
    for side in ('top','left','bottom','right'):
        el = OxmlElement(f'w:{side}')
        el.set(qn('w:val'),   'single')
        el.set(qn('w:sz'),    '4')
        el.set(qn('w:space'), '0')
        el.set(qn('w:color'), color)
        tcBorders.append(el)
    tcPr.append(tcBorders)

def heading1(text):
    p = doc.add_paragraph()
    p.paragraph_format.space_before = Pt(18)
    p.paragraph_format.space_after  = Pt(6)
    run = p.add_run(text)
    run.font.size  = Pt(16)
    run.font.bold  = True
    run.font.color.rgb = BLUE
    run.font.name  = '맑은 고딕'
    # 하단 테두리
    pPr = p._p.get_or_add_pPr()
    pBdr = OxmlElement('w:pBdr')
    bottom = OxmlElement('w:bottom')
    bottom.set(qn('w:val'),   'single')
    bottom.set(qn('w:sz'),    '6')
    bottom.set(qn('w:space'), '4')
    bottom.set(qn('w:color'), '2563EB')
    pBdr.append(bottom)
    pPr.append(pBdr)
    return p

def heading2(text):
    p = doc.add_paragraph()
    p.paragraph_format.space_before = Pt(12)
    p.paragraph_format.space_after  = Pt(4)
    run = p.add_run(text)
    run.font.size  = Pt(13)
    run.font.bold  = True
    run.font.color.rgb = DARK
    run.font.name  = '맑은 고딕'
    return p

def heading3(text):
    p = doc.add_paragraph()
    p.paragraph_format.space_before = Pt(8)
    p.paragraph_format.space_after  = Pt(2)
    run = p.add_run(text)
    run.font.size  = Pt(11.5)
    run.font.bold  = True
    run.font.color.rgb = BLUE
    run.font.name  = '맑은 고딕'
    return p

def body(text, bold=False, color=None, size=10.5):
    p = doc.add_paragraph()
    p.paragraph_format.space_after = Pt(4)
    run = p.add_run(text)
    run.font.size  = Pt(size)
    run.font.bold  = bold
    run.font.name  = '맑은 고딕'
    if color:
        run.font.color.rgb = color
    return p

def bullet(text, level=0):
    p = doc.add_paragraph(style='List Bullet')
    p.paragraph_format.left_indent   = Cm(0.5 + level * 0.5)
    p.paragraph_format.space_after   = Pt(3)
    run = p.add_run(text)
    run.font.size = Pt(10.5)
    run.font.name = '맑은 고딕'
    return p

def info_box(text, bg='EFF6FF', border='BFDBFE'):
    p = doc.add_paragraph()
    p.paragraph_format.space_before = Pt(6)
    p.paragraph_format.space_after  = Pt(6)
    p.paragraph_format.left_indent  = Cm(0.3)
    run = p.add_run(text)
    run.font.size = Pt(10)
    run.font.name = '맑은 고딕'
    run.font.color.rgb = RGBColor(0x1E, 0x40, 0xAF)
    pPr = p._p.get_or_add_pPr()
    shd = OxmlElement('w:shd')
    shd.set(qn('w:val'),   'clear')
    shd.set(qn('w:color'), 'auto')
    shd.set(qn('w:fill'),  bg)
    pPr.append(shd)
    return p

def spacer(n=1):
    for _ in range(n):
        p = doc.add_paragraph()
        p.paragraph_format.space_after = Pt(0)
        run = p.add_run('')
        run.font.size = Pt(4)

def make_table(headers, rows, col_widths_cm):
    t = doc.add_table(rows=1+len(rows), cols=len(headers))
    t.style = 'Table Grid'
    t.alignment = WD_TABLE_ALIGNMENT.LEFT
    # 헤더행
    hrow = t.rows[0]
    for i, h in enumerate(headers):
        cell = hrow.cells[i]
        cell.width = Cm(col_widths_cm[i])
        set_cell_bg(cell, '2563EB')
        set_cell_border(cell, '2563EB')
        p = cell.paragraphs[0]
        p.paragraph_format.space_before = Pt(4)
        p.paragraph_format.space_after  = Pt(4)
        run = p.add_run(h)
        run.font.bold  = True
        run.font.size  = Pt(10)
        run.font.color.rgb = WHITE
        run.font.name  = '맑은 고딕'
        p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    # 데이터행
    for ri, row in enumerate(rows):
        bg = 'FFFFFF' if ri % 2 == 0 else 'F8FAFC'
        drow = t.rows[ri+1]
        for ci, val in enumerate(row):
            cell = drow.cells[ci]
            cell.width = Cm(col_widths_cm[ci])
            set_cell_bg(cell, bg)
            set_cell_border(cell, 'E2E8F0')
            p = cell.paragraphs[0]
            p.paragraph_format.space_before = Pt(3)
            p.paragraph_format.space_after  = Pt(3)
            run = p.add_run(val)
            run.font.size = Pt(10)
            run.font.name = '맑은 고딕'
    return t


# ════════════════════════════════════════════════════════════
# 표지
# ════════════════════════════════════════════════════════════
p = doc.add_paragraph()
p.paragraph_format.space_before = Pt(80)
p.paragraph_format.space_after  = Pt(8)
p.alignment = WD_ALIGN_PARAGRAPH.CENTER
run = p.add_run('🏨  시흥 웨이브파크')
run.font.size  = Pt(14)
run.font.color.rgb = GRAY
run.font.name  = '맑은 고딕'

p2 = doc.add_paragraph()
p2.alignment = WD_ALIGN_PARAGRAPH.CENTER
p2.paragraph_format.space_after = Pt(16)
run2 = p2.add_run('하자관리 시스템 사용 설명서')
run2.font.size  = Pt(26)
run2.font.bold  = True
run2.font.color.rgb = DARK
run2.font.name  = '맑은 고딕'

p3 = doc.add_paragraph()
p3.alignment = WD_ALIGN_PARAGRAPH.CENTER
p3.paragraph_format.space_after = Pt(60)
run3 = p3.add_run('관리자 및 직원 공용  |  2026년 6월')
run3.font.size  = Pt(11)
run3.font.color.rgb = GRAY
run3.font.name  = '맑은 고딕'

doc.add_page_break()


# ════════════════════════════════════════════════════════════
# 1. 이 시스템을 왜 만들었나
# ════════════════════════════════════════════════════════════
heading1('1. 이 시스템을 왜 만들었나')
body('시흥 웨이브파크 객실에서 발생하는 하자(결함, 고장, 파손)를 엑셀·수기 메모 대신 하나의 디지털 플랫폼에서 통합 관리하기 위해 제작되었습니다.')
spacer()
body('도입 전 문제점:', bold=True)
bullet('담당자가 바뀌면 하자 이력이 사라지거나 인수인계가 누락됨')
bullet('외주업체 처리비용이 분산 기록되어 월말 집계가 어려움')
bullet('어떤 공종(전기, 설비 등)에서 하자가 집중되는지 파악 불가')
bullet('같은 객실에 반복적으로 동일 하자가 발생해도 인지하지 못함')
bullet('방막(판매 불가 상태) 기간이 기록되지 않아 손실 규모 미파악')
spacer()
body('도입 후 기대 효과:', bold=True)
bullet('모든 하자를 실시간으로 등록·조회·상태 관리')
bullet('공종별·객실별 통계로 반복 문제 조기 발견')
bullet('자체 처리 vs 외주 처리 비용 분리 집계')
bullet('부품 재고 현황 파악 및 발주 기준 설정')
bullet('수정이력 보관으로 책임 소재 명확화')
spacer()


# ════════════════════════════════════════════════════════════
# 2. 시스템 구성 개요
# ════════════════════════════════════════════════════════════
heading1('2. 시스템 구성 개요')
body('본 시스템은 별도 설치 없이 웹 브라우저에서 접속하는 형태입니다.')
spacer()

make_table(
    ['구성 요소', '역할', '비고'],
    [
        ['GitHub Pages', '웹 사이트 호스팅 (무료)', 'URL로 접속'],
        ['Supabase', '데이터베이스 및 로그인 관리', '클라우드 PostgreSQL'],
        ['브라우저', '사용 환경 (Chrome 권장)', '앱 설치 불필요'],
    ],
    [5, 7, 4]
)
spacer()
info_box('💡  인터넷이 연결된 환경이면 PC·태블릿·스마트폰 모두 접속 가능합니다.')
spacer()


# ════════════════════════════════════════════════════════════
# 3. 로그인 및 계정 관리
# ════════════════════════════════════════════════════════════
heading1('3. 로그인 및 계정 관리')

heading2('3-1. 로그인 방법')
bullet('사이트 접속 시 자동으로 로그인 화면이 표시됩니다.')
bullet('이메일 주소와 비밀번호를 입력하고 로그인 버튼을 누릅니다.')
bullet('로그인 상태는 브라우저가 유지하므로, 같은 기기에서는 재로그인 없이 사용할 수 있습니다.')
spacer()

heading2('3-2. 계정 종류')
make_table(
    ['구분', '계정 수', '접근 가능 메뉴', '특이사항'],
    [
        ['관리자 (admin)', '1개', '전체 메뉴 + 🛡️ 관리자 탭', '최상위 권한'],
        ['일반 직원 (staff)', '최대 8개', '대시보드, 하자 리스트, 공종별 통계, 부품 재고, 기준정보', '관리자 탭 접근 불가'],
    ],
    [3.5, 2.5, 7, 3]
)
spacer()

heading2('3-3. 비밀번호 변경')
bullet('로그인 후 우측 상단 🔑 비밀번호 변경 버튼을 클릭합니다.')
bullet('새 비밀번호를 두 번 입력하고 변경 버튼을 누릅니다. (6자 이상)')
spacer()

heading2('3-4. 비밀번호 분실 시')
bullet('관리자에게 연락합니다.')
bullet('관리자는 🛡️ 관리자 탭 → 사용자 관리에서 해당 계정의 초기화 버튼을 눌러 임시 비밀번호(Wavepk0000!)로 초기화합니다.')
bullet('초기화 후 반드시 본인이 직접 비밀번호를 변경하세요.')
spacer()


# ════════════════════════════════════════════════════════════
# 4. 화면 구성 및 탭 설명
# ════════════════════════════════════════════════════════════
heading1('4. 화면 구성 및 탭 설명')

heading2('4-1. 상단 메뉴 탭')
make_table(
    ['탭 이름', '주요 내용'],
    [
        ['📊 대시보드', '전체 현황 요약, KPI 수치, 오늘 처리할 항목, 부품 재고 경고, 추이 차트'],
        ['객실별 하자 리스트', '전체 하자 목록, 필터 검색, 상태 변경, 하자 등록/수정/삭제'],
        ['공종별 통계', '9개 공종별 발생 건수·비용 분석, 월별 추이, 외주업체 현황'],
        ['🔧 부품 재고관리', '부품 현황, 입고/출고 등록, 재고 실사 조정, 발주 기준 설정'],
        ['기준정보 관리', '객실 정보, 공종, 하자부위, 부품, 직원 목록 등 기준 데이터 관리'],
        ['🛡️ 관리자 (admin 전용)', '사용자 관리, 하자 수정이력, Supabase 연결 설정'],
    ],
    [5, 11]
)
spacer()

heading2('4-2. 대시보드 주요 지표 (KPI)')
make_table(
    ['지표', '설명'],
    [
        ['미완료 하자', '접수·확인·조치중 상태인 하자의 총 건수'],
        ['긴급 우선순위', '우선순위가 "긴급"으로 등록된 미완료 하자 수'],
        ['외주 처리중', '외주업체에 의뢰 중인 미완료 하자 수'],
        ['이번달 완료', '해당 월에 완료 처리된 하자 수'],
        ['방막중 객실', '현재 방막(판매 불가) 상태의 하자가 있는 객실 수'],
        ['총 방막일수', '모든 하자의 방막 기간 합산 (누적)'],
        ['반복하자 건수', '같은 객실·공종에서 30일 이내 재발한 하자 수'],
        ['반복하자율', '전체 하자 중 반복하자 비율 (%)'],
    ],
    [5, 11]
)
spacer()


# ════════════════════════════════════════════════════════════
# 5. 하자 등록 방법
# ════════════════════════════════════════════════════════════
heading1('5. 하자 등록 방법')

heading2('5-1. 등록 절차')
body('객실별 하자 리스트 탭 → 우측 상단 하자 등록 버튼 클릭')
spacer()

make_table(
    ['입력 항목', '필수', '설명'],
    [
        ['객실 선택', '✅', '객실번호 또는 타입코드(예: SLF)로 검색하여 선택'],
        ['공종', '✅', '하자가 발생한 작업 분야 선택 (9가지 중 택1)'],
        ['하자부위', '', '공종 내 세부 위치 (예: 전등, 샤워기 등)'],
        ['하자 내용', '✅', '발생한 문제를 구체적으로 입력'],
        ['우선순위', '✅', '긴급 / 높음 / 보통 / 낮음 중 선택'],
        ['처리방식', '✅', '자체처리(직원이 직접) 또는 외주처리(업체 의뢰) 선택'],
        ['방막 여부', '', '해당 하자로 인해 객실 판매가 불가한 경우 체크'],
        ['방막 기간', '', '방막 여부 체크 시 판매 불가 일수 입력'],
        ['예정일', '', '처리 완료 목표일 설정'],
        ['담당자', '', '처리 담당 직원 선택'],
        ['등록자', '', '하자를 발견·등록한 직원 선택'],
        ['외주 처리비', '', '처리방식이 외주일 때 청구된 총 비용 입력'],
        ['사용 부속', '', '처리방식이 자체일 때 사용한 부품과 수량, 공임비 입력'],
    ],
    [4, 1.5, 10.5]
)
spacer()

heading2('5-2. 처리방식 선택 기준')
make_table(
    ['처리방식', '언제 선택', '비용 입력 방식'],
    [
        ['자체처리', '내부 직원이 직접 수리', '사용 부속 + 공임비를 항목별로 입력 → 자동 합산'],
        ['외주처리', '외부 업체에 의뢰', '업체로부터 받은 청구 금액 1건으로 입력'],
    ],
    [3.5, 5.5, 7]
)
spacer()


# ════════════════════════════════════════════════════════════
# 6. 하자 상태 관리
# ════════════════════════════════════════════════════════════
heading1('6. 하자 상태 관리')
body('하자는 4단계 상태로 관리됩니다. 목록에서 상태 드롭다운을 직접 변경하거나, 수정 모달에서 변경할 수 있습니다.')
spacer()

make_table(
    ['상태', '의미', '다음 단계'],
    [
        ['🔴 접수', '하자가 등록된 초기 상태', '확인'],
        ['🟡 확인', '담당자가 내용을 확인한 상태', '조치중'],
        ['🔵 조치중', '수리·처리가 진행 중인 상태', '완료'],
        ['🟢 완료', '하자가 처리되어 종료된 상태', '(종료)'],
    ],
    [3, 8, 5]
)
spacer()
info_box('💡  완료 상태로 변경하면 해당 하자는 KPI 집계에서 제외됩니다. 방막이 해소된 경우에만 완료로 변경하세요.')
spacer()


# ════════════════════════════════════════════════════════════
# 7. 부품 재고관리
# ════════════════════════════════════════════════════════════
heading1('7. 부품 재고관리')

heading2('7-1. 개요')
body('하자 수리에 사용되는 부품의 재고를 실시간으로 관리합니다. 하자에 부품을 사용으로 등록하면 재고가 자동 차감됩니다.')
spacer()

heading2('7-2. 주요 기능')
make_table(
    ['기능', '설명'],
    [
        ['부품 등록', '기준정보 관리 → 부품 탭에서 부품명, 단가, 공종, 단위 등록'],
        ['입고 등록', '부품 재고관리 탭 → 입고 등록: 부품·수량·입고단가 입력 → 재고 자동 증가'],
        ['일반 출고', '폐기, 분실, 이동 등 하자 수리 외 출고 사유 기록 → 재고 자동 감소'],
        ['재고 실사', '실제 수량과 시스템 수량이 다를 때 실사값으로 조정'],
        ['발주 기준', '안전계수(기본 1.5배) 적용하여 발주 필요 부품 자동 표시'],
    ],
    [4, 12]
)
spacer()

heading2('7-3. 발주 기준 계산 방식')
body('발주 필요 기준량 = 월평균 사용량 × 안전계수(기본 1.5)')
bullet('등록 후 3개월간: 처음 입력한 예상 월평균 사용량을 기준으로 계산')
bullet('3개월 경과 후: 실제 사용 이력 기반 이동평균으로 자동 전환')
bullet('안전계수는 🛡️ 관리자 탭 → 연결설정 또는 기준정보에서 조정 가능')
spacer()


# ════════════════════════════════════════════════════════════
# 8. 기준정보 관리
# ════════════════════════════════════════════════════════════
heading1('8. 기준정보 관리')
body('시스템에서 사용하는 기준 데이터를 관리합니다. 관리자만 추가·수정·삭제가 가능합니다.')
spacer()

make_table(
    ['서브탭', '관리 항목'],
    [
        ['객실정보', '객실번호·타입 목록. 엑셀 업로드로 일괄 등록 가능 (1열: 타입코드, 2열: 객실번호)'],
        ['객실타입', '객실 타입명과 영문 타입코드 관리 (예: 스튜디오 로프트 / SL)'],
        ['공종', '9가지 하자 분류 카테고리 (목공, 전기·조명, 설비·배관 등)'],
        ['하자부위', '공종별 세부 위치 목록 (예: 전기 > 전등, 콘센트 등)'],
        ['부품', '수리에 사용되는 부품 목록, 단가, 재고 기준'],
        ['직원', '담당자·등록자 선택 목록에 표시될 직원 이름과 직책'],
    ],
    [3.5, 12.5]
)
spacer()

heading2('객실 엑셀 일괄 등록 방법')
bullet('엑셀 파일을 준비합니다. 1열 = 타입코드(예: SLF), 2열 = 객실번호(예: 1001)')
bullet('기준정보 관리 → 객실정보 탭 → 엑셀 업로드 버튼 클릭')
bullet('파일 선택 후 자동 등록됩니다. 이미 존재하는 객실은 건너뜁니다.')
bullet('등록 후 선택삭제 버튼으로 체크한 객실을 일괄 삭제할 수 있습니다.')
spacer()


# ════════════════════════════════════════════════════════════
# 9. 관리자 전용 기능 (🛡️ 관리자 탭)
# ════════════════════════════════════════════════════════════
heading1('9. 관리자 전용 기능 (🛡️ 관리자 탭)')
body('관리자(admin) 계정으로 로그인한 경우에만 상단 탭에 표시됩니다.')
spacer()

heading2('9-1. 사용자 관리')
bullet('현재 시스템에 등록된 모든 계정 목록을 조회할 수 있습니다.')
bullet('각 계정의 이메일, 권한(관리자/일반), 마지막 로그인 일시, 가입일을 확인합니다.')
bullet('권한 변경: 일반 ↔ 관리자 권한을 즉시 변경할 수 있습니다.')
bullet('비밀번호 초기화: 초기화 버튼 클릭 → 이메일 자동 입력 → 임시 비밀번호(Wavepk0000!)로 초기화됩니다.')
info_box('⚠️  본인 계정은 권한 변경 및 비밀번호 초기화가 불가합니다.')
spacer()

heading2('9-2. 수정이력')
bullet('모든 하자의 등록·수정·삭제 이력이 자동으로 기록됩니다.')
bullet('누가 언제 어떤 하자를 어떻게 변경했는지 추적할 수 있습니다.')
bullet('액션 유형(등록/수정/삭제)과 처리자 이메일로 필터링하여 조회합니다.')
spacer()

heading2('9-3. 연결설정')
bullet('Supabase Project URL과 anon key를 브라우저에 저장합니다.')
bullet('최초 1회만 설정하면 이후 자동으로 연결됩니다.')
spacer()


# ════════════════════════════════════════════════════════════
# 10. 용어 설명
# ════════════════════════════════════════════════════════════
heading1('10. 용어 설명')

make_table(
    ['용어', '설명'],
    [
        ['하자', '객실 내 결함, 파손, 고장 등 수리가 필요한 상태 전반'],
        ['공종', '하자의 분류 기준이 되는 작업 분야. 9가지: 목공 / 전기·조명 / 설비·배관 / 도장·마감 / 타일·욕실 / 도어·하드웨어 / 가전 / 바닥재 / 기타'],
        ['하자부위', '공종 내 더 세부적인 위치 (예: 전기 공종 → 콘센트, 전등, 분전함 등)'],
        ['방막', '하자로 인해 해당 객실을 판매(예약 배정)할 수 없는 상태. 방막 기간은 수익 손실과 직결됨'],
        ['방막일수', '객실이 방막 상태로 유지된 기간(일수)'],
        ['반복하자', '같은 객실의 같은 공종에서 30일 이내에 재발한 하자. 자동으로 감지되어 표시됨'],
        ['자체처리', '내부 직원이 직접 수리하는 방식. 부품과 공임비를 항목별로 입력'],
        ['외주처리', '외부 전문 업체에 수리를 의뢰하는 방식. 업체 청구금액을 단일 금액으로 입력'],
        ['외주 처리비', '외주처리 시 업체로부터 청구된 총 비용 (출장비 + 수리비 포함)'],
        ['SLA', 'Service Level Agreement. 우선순위별로 처리 완료까지 허용되는 목표 시간. 긴급 4시간 / 높음 24시간 / 보통 72시간 / 낮음 168시간'],
        ['SLA 배지', '하자 목록에서 SLA 기준 초과 여부를 색상으로 표시. 🟢 정상 / 🟡 임박 / 🔴 초과'],
        ['안전계수', '발주 기준량 산정 시 월평균 사용량에 곱하는 배수. 기본값 1.5 (재고 부족 방지용 여유분)'],
        ['입고', '부품을 새로 구매하여 재고에 추가하는 행위'],
        ['출고', '폐기·분실·이동 등 하자 수리 외 사유로 재고에서 부품이 나가는 행위'],
        ['재고 실사', '실제 보유 수량과 시스템 수량을 대조하여 오차를 보정하는 작업'],
        ['타입코드', '객실 타입의 영문 약칭 (예: 스튜디오 로프트 → SL, 스튜디오 로프트 패밀리 → SLF)'],
        ['KPI', 'Key Performance Indicator. 핵심 성과 지표. 대시보드 상단의 숫자 카드들'],
        ['admin', '관리자 계정. 수정이력·사용자 관리·연결설정 등 전체 기능 접근 가능'],
        ['staff', '일반 직원 계정. 하자 등록·조회·상태 변경 등 일반 업무 기능 사용 가능'],
        ['Supabase', '본 시스템의 데이터베이스 및 로그인 인증을 담당하는 클라우드 서비스'],
    ],
    [4, 12]
)
spacer()


# ════════════════════════════════════════════════════════════
# 11. 자주 묻는 질문 (FAQ)
# ════════════════════════════════════════════════════════════
heading1('11. 자주 묻는 질문 (FAQ)')

heading3('Q. 로그인이 안 됩니다.')
body('이메일 주소와 비밀번호를 확인하세요. 비밀번호를 잊으셨다면 관리자에게 초기화를 요청하세요.')
spacer()

heading3('Q. 등록한 하자가 화면에 보이지 않습니다.')
body('페이지를 새로고침(F5 또는 Cmd+R)하거나 필터가 설정되어 있는지 확인하세요. 필터 초기화 버튼으로 전체 목록을 다시 불러올 수 있습니다.')
spacer()

heading3('Q. 객실 목록에 원하는 객실이 없습니다.')
body('기준정보 관리 → 객실정보 탭에서 해당 객실을 먼저 등록해야 합니다. 엑셀 파일로 일괄 등록도 가능합니다.')
spacer()

heading3('Q. 외주처리로 등록했는데 비용이 0원으로 표시됩니다.')
body('처리방식을 외주처리로 선택하면 "외주 처리비" 입력 칸이 나타납니다. 해당 칸에 청구 금액을 입력해주세요.')
spacer()

heading3('Q. 반복하자가 자동으로 표시되지 않습니다.')
body('반복하자는 같은 객실·공종에서 30일 이내 재발한 경우 등록 시점에 자동 감지됩니다. 이미 등록된 이전 하자와 조건이 맞는지 확인하세요.')
spacer()

heading3('Q. 부품 재고가 실제와 다릅니다.')
body('부품 재고관리 탭 → 재고 실사 섹션에서 실제 수량을 입력하면 시스템 재고를 실사값으로 조정할 수 있습니다.')
spacer()

heading3('Q. 관리자 탭이 보이지 않습니다.')
body('관리자(admin) 계정으로 로그인한 경우에만 표시됩니다. 일반 직원 계정은 해당 탭에 접근할 수 없습니다.')
spacer()

heading3('Q. 비밀번호를 변경하고 싶습니다.')
body('로그인 후 우측 상단 🔑 비밀번호 변경 버튼을 클릭하면 됩니다.')
spacer()


# ════════════════════════════════════════════════════════════
# 푸터
# ════════════════════════════════════════════════════════════
spacer(2)
p_footer = doc.add_paragraph()
p_footer.alignment = WD_ALIGN_PARAGRAPH.CENTER
run_f = p_footer.add_run('시흥 웨이브파크 하자관리 시스템  |  문의: 관리자(mac.lee@handys.co.kr)')
run_f.font.size = Pt(9)
run_f.font.color.rgb = GRAY
run_f.font.name = '맑은 고딕'


# ── 저장 ─────────────────────────────────────────────────
output = '/sessions/practical-magical-cerf/mnt/outputs/하자관리시스템_사용설명서.docx'
doc.save(output)
print('Done:', output)
