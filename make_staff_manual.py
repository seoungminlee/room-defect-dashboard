# -*- coding: utf-8 -*-
# 사용설명서 생성 — 전 직원 공용 (v2.7.18 기준, 2026-07)
# 실행: python3 make_staff_manual.py
#   → 하자관리시스템_사용설명서.docx 생성
#   → soffice --headless --convert-to pdf 로 PDF 변환 (스크립트가 자동 실행)
from docx import Document
from docx.shared import Pt, RGBColor, Cm
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.table import WD_TABLE_ALIGNMENT
from docx.oxml.ns import qn
from docx.oxml import OxmlElement
import os, subprocess, sys

FONT = 'Noto Sans CJK KR'

doc = Document()
section = doc.sections[0]
section.page_width  = Cm(21); section.page_height = Cm(29.7)
for m in ('left_margin','right_margin','top_margin','bottom_margin'):
    setattr(section, m, Cm(2.2))

BLUE  = RGBColor(0x25,0x63,0xEB); DARK = RGBColor(0x1C,0x1F,0x24)
GRAY  = RGBColor(0x6B,0x72,0x80); WHITE = RGBColor(0xFF,0xFF,0xFF)

def _set_font(run, size=10.5, bold=False, color=None):
    run.font.size = Pt(size); run.font.bold = bold; run.font.name = FONT
    run._element.rPr.rFonts.set(qn('w:eastAsia'), FONT)
    if color: run.font.color.rgb = color

def set_cell_bg(cell, hex_color):
    shd = OxmlElement('w:shd'); shd.set(qn('w:val'),'clear')
    shd.set(qn('w:color'),'auto'); shd.set(qn('w:fill'),hex_color)
    cell._tc.get_or_add_tcPr().append(shd)

def heading1(text):
    p = doc.add_paragraph(); p.paragraph_format.space_before = Pt(16); p.paragraph_format.space_after = Pt(6)
    r = p.add_run(text); _set_font(r, 15, True, BLUE)
    pBdr = OxmlElement('w:pBdr'); b = OxmlElement('w:bottom')
    b.set(qn('w:val'),'single'); b.set(qn('w:sz'),'6'); b.set(qn('w:space'),'4'); b.set(qn('w:color'),'2563EB')
    pBdr.append(b); p._p.get_or_add_pPr().append(pBdr)

def heading2(text):
    p = doc.add_paragraph(); p.paragraph_format.space_before = Pt(10); p.paragraph_format.space_after = Pt(3)
    _set_font(p.add_run(text), 12, True, DARK)

def body(text, bold=False, color=None, size=10.5):
    p = doc.add_paragraph(); p.paragraph_format.space_after = Pt(4)
    _set_font(p.add_run(text), size, bold, color)

def bullet(text):
    p = doc.add_paragraph(style='List Bullet')
    p.paragraph_format.left_indent = Cm(0.5); p.paragraph_format.space_after = Pt(3)
    _set_font(p.add_run(text), 10.5)

def info_box(text, fill='EFF6FF', color=RGBColor(0x1E,0x40,0xAF)):
    p = doc.add_paragraph(); p.paragraph_format.space_before = Pt(6); p.paragraph_format.space_after = Pt(6)
    _set_font(p.add_run(text), 10, color=color)
    shd = OxmlElement('w:shd'); shd.set(qn('w:val'),'clear'); shd.set(qn('w:color'),'auto'); shd.set(qn('w:fill'),fill)
    p._p.get_or_add_pPr().append(shd)

def warn_box(text):
    info_box(text, fill='FEF9C3', color=RGBColor(0x85,0x4D,0x0E))

def make_table(headers, rows, widths):
    t = doc.add_table(rows=1+len(rows), cols=len(headers))
    t.style = 'Table Grid'; t.alignment = WD_TABLE_ALIGNMENT.LEFT
    for i,h in enumerate(headers):
        c = t.rows[0].cells[i]; c.width = Cm(widths[i]); set_cell_bg(c,'2563EB')
        p = c.paragraphs[0]; p.alignment = WD_ALIGN_PARAGRAPH.CENTER
        _set_font(p.add_run(h), 10, True, WHITE)
    for ri,row in enumerate(rows):
        bg = 'FFFFFF' if ri%2==0 else 'F8FAFC'
        for ci,val in enumerate(row):
            c = t.rows[ri+1].cells[ci]; c.width = Cm(widths[ci]); set_cell_bg(c,bg)
            _set_font(c.paragraphs[0].add_run(val), 10)

# ═══ 표지 ═══
p = doc.add_paragraph(); p.paragraph_format.space_before = Pt(90); p.alignment = WD_ALIGN_PARAGRAPH.CENTER
_set_font(p.add_run('시흥 웨이브파크'), 13, color=GRAY)
p = doc.add_paragraph(); p.alignment = WD_ALIGN_PARAGRAPH.CENTER; p.paragraph_format.space_after = Pt(14)
_set_font(p.add_run('하자관리 시스템 사용설명서'), 25, True, DARK)
p = doc.add_paragraph(); p.alignment = WD_ALIGN_PARAGRAPH.CENTER
_set_font(p.add_run('전 직원 공용  |  2026년 7월  |  시스템 v2.7.18 기준'), 11, color=GRAY)
doc.add_page_break()

# ═══ 1. 로그인과 첫 시작 ═══
heading1('1. 로그인과 첫 시작')
heading2('1-1. 계정을 처음 받았을 때')
bullet('관리자가 이메일로 초대장을 보내면, 메일의 링크를 클릭합니다.')
bullet('링크를 클릭하면 자동으로 로그인되며, 이름과 사용할 비밀번호를 정하는 화면이 뜹니다.')
bullet('이 화면은 닫기 버튼을 눌러도 닫히지 않습니다. 이름·비밀번호 설정을 완료해야만 실제 대시보드 화면이 열립니다.')
bullet('비밀번호 규칙: 8자 이상, 영문과 숫자를 모두 포함해야 합니다.')
heading2('1-2. 비밀번호를 잊었을 때')
bullet('관리자에게 요청하면 임시 비밀번호를 받을 수 있습니다.')
bullet('임시 비밀번호로 로그인하면 새 비밀번호를 정하는 화면이 똑같이 강제로 뜹니다. 완료해야 이용할 수 있습니다.')
heading2('1-3. 권한 3단계')
make_table(['권한','할 수 있는 것'], [
    ['관리자(admin)','전체 기능 + 사용자 관리·백업·초기화 등 관리자 전용 기능'],
    ['일반(staff)','하자 등록·수정·삭제, 입출고·재고조정, 기준정보 등록·수정(기준정보 삭제는 불가), 공지 작성'],
    ['조회전용(viewer)','모든 화면을 볼 수만 있음. 등록·수정·삭제 전부 차단'],
], [3,13])
info_box('💡 저장이 안 되고 "권한이 없습니다. 관리자에게 문의하십시오." 메시지가 뜬다면 오류가 아니라 계정 권한상 정상 동작입니다. 필요하면 관리자에게 권한 변경을 요청하세요.')

# ═══ 2. 화면 구성 ═══
heading1('2. 화면 구성')
make_table(['탭','내용'], [
    ['현황','전체 요약 KPI, 오늘 처리할 항목, 부품 재고 경고, 반복하자 목록, 내 담당 처리기한 초과 알림'],
    ['하자 목록','전체 하자 조회·검색·필터, 상태 변경, 등록·수정'],
    ['공지','공지사항 등록·조회'],
    ['부품 재고관리','부품 현황, 입고·출고 등록, 재고 실사/조정'],
    ['분석 > 증상별 통계','하자증상별 발생 건수·비용, 하자부위별 집계'],
    ['분석 > 비용·부품 통계','월별 비용 추이, 부품 사용 현황'],
    ['분석 > 외주업체','외주업체별 처리 현황·비용, 업체 등록·서류 관리'],
    ['분석 > 보고서','기간별 종합 리포트, 엑셀 다운로드'],
    ['설정 > 기준정보','객실·객실타입·하자부위·하자증상·수리부속·직원 목록 관리'],
], [4.5,11.5])
heading2('모바일 화면')
bullet('스마트폰으로 접속하면 전용 홈 화면이 뜹니다: 하자 등록 버튼, 하자 목록·입출고·공지 바로가기, 조치 필요 목록, 내 하자 목록.')
bullet('처음 접속 시 하단에 "홈 화면에 추가" 안내 배너가 뜹니다. 앱처럼 아이콘으로 설치할 수 있으며, X로 닫으면 다시 뜨지 않습니다.')

# ═══ 3. 현황(대시보드) 화면 ═══
heading1('3. 현황(대시보드) 화면')
heading2('3-1. 핵심 지표(KPI)')
make_table(['지표','설명'], [
    ['미완료 하자','접수·확인·조치중 상태인 하자 총 건수 (클릭 시 목록으로 이동)'],
    ['긴급 우선순위','우선순위 "긴급"이면서 미완료인 하자 건수 (클릭 시 필터된 목록으로 이동)'],
    ['외주 처리중','외주업체에 의뢰 중인 미완료 하자 수'],
    ['이번달 완료','이번 달에 완료 처리된 하자 수'],
    ['방막중 객실','현재 방막(판매 불가) 상태인 객실 수'],
    ['총 방막일수','모든 하자의 방막 기간 합산(누적)'],
    ['반복하자 건수 / 반복하자율','같은 객실에서 최근 30일 내 재발한 하자 수와 비율'],
    ['평균 처리일','완료된 하자의 등록~완료까지 평균 소요일'],
    ['처리기한 임박','예정일이 오늘부터 일정 기간(기본 3일) 이내로 다가온 미완료 하자 수'],
], [4.5,11.5])
heading2('3-2. 내 담당 처리기한 초과 알림')
bullet('로그인할 때마다 본인 담당(담당자로 지정된) 하자 중 예정일이 지난 건이 자동으로 스캔됩니다.')
bullet('해당 건이 있으면 현황 화면 상단에 빨간 알림 배너로 표시됩니다. 클릭하면 바로 그 하자의 상세 화면으로 이동합니다.')
bullet('닫기(X)를 눌러도 그 세션에서만 숨겨질 뿐, 다음 로그인 시 여전히 처리 안 된 상태면 다시 표시됩니다.')
info_box('💡 이 알림은 본인에게만 보입니다. 다른 직원의 담당 건은 뜨지 않습니다.')

# ═══ 4. 하자 등록 ═══
heading1('4. 하자 등록')
heading2('4-1. 등록 절차')
body('하자 목록 탭 → "+ 하자 등록" 버튼 클릭')
make_table(['입력 항목','필수','설명'], [
    ['객실', '✅', '객실번호 일부를 입력하면 일치하는 객실만 자동으로 좁혀져 표시됩니다 (예: "12" 입력 시 1212·1208·1308 등)'],
    ['하자증상', '✅', '기준정보에 등록된 목록 중 선택 (기준정보 > 하자증상 탭에서 관리자·직원이 추가/수정 가능)'],
    ['하자부위', '', '기준정보에 등록된 부위 목록 중 선택 (선택사항)'],
    ['하자 제목', '✅', '한 줄 요약'],
    ['우선순위', '', '긴급 / 높음 / 보통 / 낮음'],
    ['상세 설명', '', '증상·위치 등 자세한 내용'],
    ['상태', '', '접수 / 확인 / 조치중 / 완료 (기본값: 접수)'],
    ['예정일', '', '처리 완료 목표일'],
    ['처리방식', '✅', '자체처리 또는 외주처리'],
    ['외주업체명', '', '처리방식이 외주일 때만 표시. 등록된 외주업체 목록에서 선택 (직접 타이핑 불가)'],
    ['외주 처리비', '', '외주처리일 때 청구된 총 비용'],
    ['사용 부속 / 발생비용', '', '자체처리일 때만 표시. 부속과 수량, 공임비를 등록하면 자동 합산 (하자를 먼저 저장한 뒤에도 추가 가능)'],
    ['방막 여부·기간', '', '해당 하자로 객실 판매가 불가한 경우 체크 후 시작일~종료일 입력. 종료일을 비워두면 "진행중"으로 보고 오늘 날짜까지 자동으로 일수가 매일 늘어남'],
    ['담당자 / 등록자', '', '직원 목록에서 선택. 등록자는 본인이 자동 선택됨'],
    ['사진', '', '최대 5장, 등록 화면에서 바로 첨부 가능 (4-3 참조)'],
], [3.5,1.3,11.2])
heading2('4-2. 외주업체명은 왜 직접 입력이 안 되나요')
bullet('예전에는 자유 입력이었지만, 오타가 나면 외주업체별 통계·비용 집계에서 같은 업체가 다른 이름으로 잡혀 누락되는 문제가 있었습니다.')
bullet('"선택" 버튼을 누르면 등록된 외주업체 목록에서 검색·선택하는 창이 뜹니다. 목록에 없는 업체는 분석 > 외주업체 탭에서 먼저 등록해야 합니다.')
heading2('4-3. 사진 첨부하기')
bullet('등록 화면 하단 "사진" 항목에서 "📷 사진 추가" 버튼을 누르면 바로 첨부할 수 있습니다 — 저장하는 순간 사진도 함께 등록됩니다.')
bullet('처리 중이거나 완료된 뒤에 사진을 추가로 남기고 싶다면, 목록에서 해당 하자를 클릭해 상세보기를 열고 같은 방식으로 "사진 추가"를 누르면 됩니다(예: 수리 완료 사진).')
bullet('모바일에서는 카메라로 바로 촬영하거나 갤러리에서 기존 사진을 선택할 수 있습니다. PC에서는 파일 선택 창이 뜹니다.')
bullet('하자 1건당 최대 5장까지 첨부할 수 있습니다. 초과분은 업로드되지 않습니다.')
bullet('사진을 누르면 새 탭에서 원본 크기로 볼 수 있고, 사진 우측 상단의 ✕ 버튼으로 개별 삭제할 수 있습니다(조회전용 계정 제외).')
bullet('사진 아래쪽의 파란 ⬇ 버튼을 누르면 그 사진 하나만 바로 기기에 저장됩니다 (우클릭 없이 다운로드).')
bullet('"⬇ 전체 다운로드" 버튼을 누르면 그 하자에 첨부된 사진 전체를 zip 파일 하나로 한 번에 저장할 수 있습니다.')
info_box('💡 업로드하면 자동으로 크기와 화질이 줄어듭니다(저장공간 절약 목적). 원본 그대로 저장되지 않으니, 원본이 꼭 필요한 경우 별도로 보관해두세요.')

# ═══ 5. 하자 상태·배지 관리 ═══
heading1('5. 하자 상태·배지 관리')
heading2('5-1. 4단계 상태')
make_table(['상태','의미'], [
    ['📥 접수','하자가 등록된 초기 상태'],
    ['🔍 확인','담당자가 내용을 확인한 상태'],
    ['🔧 조치중','수리·처리가 진행 중인 상태'],
    ['✅ 완료','처리가 끝나 종료된 상태 (KPI 집계에서 제외)'],
], [3,13])
bullet('하자 목록에서 상태 드롭다운을 바로 바꾸거나, 수정 화면에서 변경할 수 있습니다.')
heading2('5-2. 경과일 배지(SLA)와 처리기한 배지는 다른 개념입니다')
make_table(['배지','기준','표시'], [
    ['경과일 배지','등록일로부터 지난 일수 (완료 전까지 계속 증가)','0~2일 정상 / 3~6일 임박 / 7일 이상 초과'],
    ['예정일 초과 배지','입력한 예정일이 지났는데 아직 미완료','예정일 초과'],
], [3.5,6,6.5])
info_box('💡 경과일 배지는 우선순위와 무관하게 등록일 기준으로만 계산됩니다. "긴급"으로 등록해도 자동으로 시간이 단축되지는 않으니, 실제 처리 순서는 우선순위와 담당자 판단으로 정하세요.')

# ═══ 6. 하자 목록 필터·검색 ═══
heading1('6. 하자 목록 필터·검색')
bullet('필터 조합: 객실 / 하자증상 / 상태 / 우선순위 / 담당자 / 등록일 기간(시작~끝) 을 동시에 좁혀서 조회할 수 있습니다.')
bullet('통합 검색창 하나로 객실번호·증상·부위·상세설명·담당자·등록자·외주업체명까지 한 번에 검색됩니다.')
bullet('"필터 초기화" 버튼으로 모든 필터와 검색어를 한 번에 지울 수 있습니다.')
info_box('💡 잘못 등록하거나 중복 등록한 하자는 목록·상세보기의 삭제 버튼으로 직접 삭제할 수 있습니다(조회전용 계정 제외). 삭제한 하자는 실제로 지워지지 않고 "휴지통"으로 이동하며, 실수로 지웠다면 관리자에게 복구를 요청하세요. 누가 언제 삭제했는지는 수정이력에도 남습니다.')

heading2('6-1. 실수로 삭제했다면 — 휴지통 복구')
bullet('직원이 삭제 버튼을 눌러도 하자는 즉시 완전히 사라지지 않습니다. "삭제되었습니다. 필요하면 휴지통에서 복구할 수 있습니다" 안내와 함께 목록에서만 빠집니다.')
bullet('복구는 관리자 권한(설정 > 관리자 > 휴지통)에서만 가능합니다. 실수로 지웠다면 관리자에게 요청하세요.')
bullet('휴지통에서 복구하면 사용 부속·상태이력·코멘트까지 삭제 전 상태 그대로 되살아납니다.')
info_box('💡 휴지통에 있는 동안에는 통계·목록 어디에도 집계되지 않습니다. 복구되기 전까지는 없는 것과 동일하게 취급됩니다.')

# ═══ 7. 부품 재고관리 ═══
heading1('7. 부품 재고관리')
heading2('7-1. 기본 흐름')
bullet('입고 등록: 부품·수량·입고단가 입력 → 재고 자동 증가. 입고자는 본인이 자동 선택됩니다.')
bullet('일반 출고: 하자 수리 외 사유(폐기·분실·이동 등)로 재고를 뺄 때 사용합니다.')
bullet('재고 실사/조정: 실제 수량과 시스템 수량이 다를 때 실사값을 입력해 맞춥니다. 실사자도 본인이 자동 선택됩니다.')
bullet('재고보다 많은 수량을 출고하려 하면 시스템이 자동으로 차단합니다.')
heading2('7-2. 재고 정정 규칙')
make_table(['상황','올바른 처리'], [
    ['실물과 시스템 수량이 다름','재고 실사/조정에서 실사값 입력 (직원 가능)'],
    ['입고·출고를 잘못 등록함','관리자에게 요청 — 관리자가 이력 삭제 시 재고가 자동으로 원복됨'],
], [6,10])
heading2('7-3. 발주 기준')
body('발주 필요 기준량 = 월평균 사용량 × 안전계수(기본 1.5)')
bullet('등록 후 3개월간은 입력한 예상 월평균 사용량을 기준으로, 이후에는 실제 사용 이력 기반으로 자동 전환됩니다.')

# ═══ 8. 공지사항 ═══
heading1('8. 공지사항')
bullet('공지 탭에서 팀 전체에 알릴 내용을 등록·조회합니다. 노출 기간을 설정할 수 있습니다.')
bullet('본인이 작성한 공지 또는 관리자만 수정·삭제할 수 있습니다.')

# ═══ 9. 기준정보 관리 (직원도 가능한 범위) ═══
heading1('9. 기준정보 관리')
body('설정 > 기준정보 탭에서 관리합니다. 아래 항목은 직원도 등록·수정할 수 있습니다 (삭제는 관리자만 가능).')
make_table(['항목','내용'], [
    ['객실정보','객실번호·타입 목록. 엑셀 일괄 등록 가능'],
    ['객실타입','타입명과 영문 타입코드'],
    ['하자부위','하자가 발생한 세부 위치 목록'],
    ['하자증상','하자 등록 시 선택하는 증상 목록. 새 유형이 필요하면 여기서 바로 추가할 수 있습니다'],
    ['수리부속·단가','부품명, 단가, 단위, 주거래처, 예상 월평균 사용량'],
], [3.5,12.5])
info_box('💡 직원 명단과 외주업체(계좌·서류 포함) 등록은 관리자만 가능합니다.')

# ═══ 10. 용어 설명 ═══
heading1('10. 용어 설명')
make_table(['용어','설명'], [
    ['하자','객실 내 결함·파손·고장 등 수리가 필요한 상태 전반'],
    ['하자증상','하자를 분류하는 기준 (예: 누수·누전, 파손·균열 등). 기준정보에서 자유롭게 추가·수정 가능'],
    ['하자부위','하자가 발생한 세부 위치 (예: 화장실 벽면, 발코니 바닥)'],
    ['방막','하자로 인해 해당 객실을 판매할 수 없는 상태. 시작일~종료일로 관리하며, 종료일이 없으면 진행중인 것으로 보고 매일 자동으로 일수가 늘어남'],
    ['반복하자','같은 객실에서 30일 이내에 재발한 하자. 등록 시 자동 감지되어 표시됨'],
    ['휴지통','삭제된 하자가 완전히 사라지지 않고 임시 보관되는 곳. 관리자만 접근 가능하며 복구 또는 영구삭제 선택'],
    ['자체처리','내부 직원이 직접 수리. 부속·공임비를 항목별로 입력해 자동 합산'],
    ['외주처리','외부 업체에 의뢰. 등록된 업체 중 선택 후 청구 금액을 단일 금액으로 입력'],
    ['경과일 배지(SLA)','등록일로부터 경과한 일수를 기준으로 한 색상 표시. 우선순위와는 무관'],
    ['예정일 초과','입력한 처리 예정일이 지났는데 아직 미완료인 상태'],
    ['안전계수','발주 기준량 계산 시 월평균 사용량에 곱하는 배수. 기본값 1.5'],
    ['admin / staff / viewer','관리자 / 일반 직원 / 조회전용 3단계 권한'],
], [4,12])

# ═══ 11. FAQ ═══
heading1('11. 자주 묻는 질문 (FAQ)')
faqs = [
    ('로그인이 안 됩니다.', '이메일과 비밀번호를 확인하세요. 비밀번호를 잊었다면 관리자에게 초기화를 요청하세요.'),
    ('저장 버튼을 눌러도 반응이 없거나 "권한이 없습니다" 메시지가 뜹니다.', '조회전용(viewer) 계정이거나, 삭제처럼 직원 권한 밖의 작업일 수 있습니다. 필요하면 관리자에게 권한을 문의하세요.'),
    ('원하는 하자증상이 목록에 없습니다.', '기준정보 > 하자증상 탭에서 직접 추가할 수 있습니다.'),
    ('외주업체명을 목록에서 찾을 수 없습니다.', '분석 > 외주업체 탭에서 먼저 등록해야 하자 등록 화면의 선택 목록에 나타납니다.'),
    ('객실 목록에 원하는 객실이 없습니다.', '기준정보 > 객실정보 탭에서 먼저 등록해야 합니다. 엑셀 일괄 등록도 가능합니다.'),
    ('부품 재고가 실제와 다릅니다.', '부품 재고관리 탭의 재고 실사/조정에서 실제 수량을 입력해 맞추세요.'),
    ('입고·출고를 잘못 등록했습니다.', '직원은 직접 삭제할 수 없습니다. 관리자에게 요청하면 이력 삭제 시 재고가 자동으로 원복됩니다.'),
    ('비밀번호를 변경하고 싶습니다.', '로그인 후 우측 상단 비밀번호 변경 버튼을 클릭하세요. (8자 이상, 영문+숫자 포함)'),
    ('하자를 실수로 삭제했습니다. 되살릴 수 있나요?', '네. 삭제된 하자는 즉시 사라지지 않고 휴지통에 보관됩니다. 관리자에게 복구를 요청하면 부속·이력·코멘트까지 그대로 되살릴 수 있습니다.'),
    ('사진을 6장 이상 올리고 싶습니다.', '하자 1건당 5장으로 제한되어 있습니다. 더 필요하면 하자를 증상별로 나눠 등록하거나, 필요성을 관리자에게 알려주세요.'),
    ('업로드한 사진이 화질이 낮아 보입니다.', '저장공간 절약을 위해 업로드 시 자동으로 리사이즈·압축됩니다. 정상 동작이며, 원본이 꼭 필요하면 별도로 보관해두세요.'),
]
for q,a in faqs:
    p = doc.add_paragraph(); p.paragraph_format.space_before = Pt(8); p.paragraph_format.space_after = Pt(2)
    _set_font(p.add_run('Q. '+q), 10.5, True, BLUE)
    body(a, size=10)

p = doc.add_paragraph(); p.alignment = WD_ALIGN_PARAGRAPH.CENTER; p.paragraph_format.space_before = Pt(24)
_set_font(p.add_run('시흥 웨이브파크 하자관리 시스템  |  문의: 관리자 (mac.lee@handys.co.kr)  |  v2.7.18 · 2026-07'), 9, color=GRAY)

here = os.path.dirname(os.path.abspath(__file__))
docx_path = os.path.join(here, '하자관리시스템_사용설명서.docx')
doc.save(docx_path)
print('docx:', docx_path)
r = subprocess.run(['soffice','--headless','--convert-to','pdf','--outdir',here,docx_path],
                   capture_output=True, text=True, timeout=120)
print(r.stdout or r.stderr)
