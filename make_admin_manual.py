# -*- coding: utf-8 -*-
# 관리자용 사용설명서 생성 (v2.6 기준, 2026-07)
# 실행: python3 make_admin_manual.py
#   → 하자관리시스템_관리자용_사용설명서.docx 생성
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
_set_font(p.add_run('하자관리 시스템 관리자용 설명서'), 25, True, DARK)
p = doc.add_paragraph(); p.alignment = WD_ALIGN_PARAGRAPH.CENTER
_set_font(p.add_run('관리자 전용  |  2026년 7월  |  시스템 v2.6 기준'), 11, color=GRAY)
doc.add_page_break()

# ═══ 1. 권한 체계 ═══
heading1('1. 권한 체계 (3단계)')
body('모든 계정은 세 가지 권한 중 하나를 가지며, 권한은 화면 숨김이 아니라 데이터베이스 차원에서 강제됩니다.')
make_table(['권한','표시명','할 수 있는 것'], [
    ['admin','관리자','전체 기능 + 관리자 탭(사용자 관리·수정이력·백업·초기화), 기준정보 삭제, 입출고 이력 삭제'],
    ['staff','일반','하자 등록·수정, 입출고·재고조정, 기준정보 등록·수정(삭제 불가), 공지 작성'],
    ['viewer','조회전용','모든 화면 조회만 가능. 등록·수정·삭제 전부 차단'],
], [2.2,2.2,12])
info_box('💡 권한이 없는 작업을 시도하면 "권한이 없습니다. 관리자에게 문의하십시오." 메시지가 뜹니다. 직원이 문의해오면 시스템 오류가 아니라 권한 설계에 따른 정상 동작입니다.')

# ═══ 2. 계정 관리 ═══
heading1('2. 계정 관리 (관리자 탭 → 사용자 관리)')
heading2('2-1. 새 계정 초대')
bullet('이메일·이름·권한을 입력하고 초대 발송을 누르면 초대 메일이 전송됩니다.')
bullet('수신자가 메일의 링크를 클릭하면 자동 로그인되며, 이름·비밀번호 설정 창이 강제로 뜹니다. 설정을 완료해야 시스템을 쓸 수 있습니다.')
bullet('임시 비밀번호를 만들어 전달할 필요가 없습니다 — 본인이 처음부터 직접 정합니다.')
warn_box('⚠️ 초대 메일이 안 오면: 스팸함 확인 → 그래도 없으면 Supabase의 SMTP(메일 발송) 설정 점검이 필요합니다.')
heading2('2-2. 권한 변경')
bullet('사용자 목록의 권한 드롭다운에서 관리자/일반/조회전용을 바로 변경합니다.')
bullet('본인 계정의 관리자 권한은 해제할 수 없습니다 (관리자 0명 사고 방지).')
bullet('변경된 권한은 대상자가 재로그인해야 적용됩니다.')
heading2('2-3. 비밀번호 초기화 (분실 시)')
bullet('사용자 목록에서 초기화 버튼 → 임시 비밀번호 입력 → 대상자에게 전달합니다.')
bullet('임시 비밀번호도 정책을 따라야 합니다: 8자 이상, 영문+숫자 포함.')
bullet('대상자가 임시 비밀번호로 로그인하면 비밀번호 변경 창이 강제로 떠서 새 비밀번호를 정해야만 사용할 수 있습니다.')
heading2('2-4. 계정 삭제')
bullet('삭제 버튼으로 계정을 완전히 제거합니다. 복구할 수 없으므로 퇴사 확정 후에만 사용하세요.')
bullet('본인 계정은 삭제할 수 없습니다.')

# ═══ 3. 수정이력 ═══
heading1('3. 수정이력 — 감사 로그 (관리자 탭)')
bullet('하자뿐 아니라 부품·입출고·객실·업체·설정 등 주요 데이터 전체의 등록/수정/삭제가 자동 기록됩니다.')
bullet('누가(이메일), 언제, 어떤 항목을, 무엇에서 무엇으로 바꿨는지 확인할 수 있습니다.')
bullet('액션·테이블·이메일로 필터링해 조회합니다.')
bullet('운영 데이터 초기화 실행도 실행자·일시·사유와 함께 "⚠️ 초기화"로 기록되며, 이 기록은 초기화해도 지워지지 않습니다.')

# ═══ 4. 데이터 백업 ═══
heading1('4. 데이터 백업 (관리자 탭 → 연결설정)')
bullet('"전체 백업 다운로드 (JSON)" 버튼 하나로 전체 데이터(22개 테이블)를 파일로 내려받습니다.')
bullet('주 1회, 그리고 데이터 초기화 전에는 반드시 백업을 받아 보관하세요.')
bullet('백업 파일에는 업체 계좌정보 등 민감 데이터가 포함되므로 공유 폴더에 두지 마세요.')

# ═══ 5. 초기화 ═══
heading1('5. 운영 데이터 초기화 (관리자 탭)')
body('시범운영 종료 등으로 하자·입출고 데이터를 전부 비울 때 사용하는 기능입니다.')
bullet('절차: 확인 문구("데이터 초기화") 입력 → 초기화 사유 입력(필수) → 실행')
bullet('삭제 대상: 하자·이력·코멘트·사진·입출고·조정·공지 (재고 수량도 0으로)')
bullet('보존 대상: 계정, 기준정보(객실·타입·부위·부품·직원·업체), 수정이력(감사 로그)')
warn_box('⚠️ 실행 전 반드시 백업을 먼저 받으세요. 초기화는 되돌릴 수 없습니다.')

# ═══ 6. 재고 정정 규칙 ═══
heading1('6. 재고 정정 운영 규칙')
make_table(['상황','올바른 처리','누가'], [
    ['실물과 시스템 수량이 다름','재고 실사/조정 탭에서 실사값 입력 (전/후·차이·실사자 기록됨)','직원 가능'],
    ['입고·출고를 잘못 등록함','관리자 탭 → 재고이력에서 해당 건 삭제 → 재고 수량 자동 원복','관리자만'],
    ['재고보다 많은 출고 시도','시스템이 자동 차단 ("재고 부족" 안내)','—'],
], [4.5,9,2.9])
bullet('이미 사용된 입고분은 삭제가 차단됩니다 — 이 경우 조정으로 수량을 맞추세요.')
bullet('입고·출고·조정 내역은 입출고 등록 화면의 "최근 입출고 이력"과 관리자 탭 재고이력에서 함께 확인됩니다.')
bullet('입고자·출고자·실사자는 로그인한 본인이 자동 선택되며, 대리 입력 시 드롭다운에서 변경합니다.')

# ═══ 7. 기준정보 권한 ═══
heading1('7. 기준정보 관리 권한')
bullet('객실·객실타입·하자부위·수리부속·발주기준의 등록과 수정은 직원도 가능합니다.')
bullet('삭제는 관리자만 가능합니다 (실수로 인한 데이터 소실 방지).')
bullet('직원 명단과 외주업체 정보(계좌·서류 포함)는 관리자만 등록·수정·삭제할 수 있습니다.')
bullet('업체 서류(사업자등록증·계좌사본·계약서)는 로그인한 사용자만 열람 가능하며, 열람 링크는 10분간만 유효합니다.')

# ═══ 8. 화면 활용 팁 ═══
heading1('8. 화면 활용 팁 (v2.0~v2.6 변경점)')
make_table(['기능','사용법'], [
    ['대시보드 바로가기','미완료·긴급 카드를 클릭하면 필터된 하자 목록으로 이동'],
    ['통합 검색','하자 목록 검색창 하나로 객실·증상·부위·내용·담당자·업체 검색'],
    ['미완료 전체 필터','상태 필터에서 "미완료 전체" 선택 시 완료 제외 전체 표시'],
    ['모바일 홈','조치 필요(긴급·기한초과) 목록, 내 하자, 입출고 등록 지원'],
    ['홈 화면 추가','모바일 하단 배너 안내에 따라 홈 화면에 앱처럼 설치 가능'],
    ['업데이트 로그','연결설정 하단에서 버전별 변경 내역 확인'],
], [4,12.4])

# ═══ 9. FAQ ═══
heading1('9. 관리자 FAQ')
faqs = [
    ('직원이 "저장이 안 된다"고 합니다.',
     '화면에 "권한이 없습니다" 안내가 떴는지 확인하세요. 떴다면 권한 설계상 정상입니다(예: 직원의 기준정보 삭제). 안내 없이 저장이 안 되면 화면 캡처와 함께 보고받아 주세요.'),
    ('권한을 바꿨는데 적용이 안 됩니다.', '대상자가 로그아웃 후 재로그인해야 새 권한이 적용됩니다.'),
    ('초대 메일이 발송되지 않습니다.', 'SMTP(메일 발송) 설정 문제일 수 있습니다. Supabase 대시보드의 SMTP 설정에서 앱 비밀번호가 유효한지 확인하세요.'),
    ('실수로 데이터를 지웠습니다.', '최근 백업 JSON이 복구 근거가 됩니다. 수정이력(감사 로그)에서 누가 언제 지웠는지 먼저 확인하세요.'),
    ('재고 숫자가 이상합니다.', '관리자 탭 재고이력에서 해당 부품의 입출고·조정 흐름을 확인하고, 실물과 다르면 재고 실사/조정으로 맞추세요.'),
    ('비밀번호 규칙이 뭔가요.', '8자 이상, 영문과 숫자를 모두 포함해야 합니다. 특수문자는 자유롭게 추가할 수 있습니다.'),
]
for q,a in faqs:
    p = doc.add_paragraph(); p.paragraph_format.space_before = Pt(8); p.paragraph_format.space_after = Pt(2)
    _set_font(p.add_run('Q. '+q), 10.5, True, BLUE)
    body(a, size=10)

p = doc.add_paragraph(); p.alignment = WD_ALIGN_PARAGRAPH.CENTER; p.paragraph_format.space_before = Pt(24)
_set_font(p.add_run('시흥 웨이브파크 하자관리 시스템  |  문의: 관리자 (mac.lee@handys.co.kr)  |  v2.6 · 2026-07'), 9, color=GRAY)

here = os.path.dirname(os.path.abspath(__file__))
docx_path = os.path.join(here, '하자관리시스템_관리자용_사용설명서.docx')
doc.save(docx_path)
print('docx:', docx_path)
r = subprocess.run(['soffice','--headless','--convert-to','pdf','--outdir',here,docx_path],
                   capture_output=True, text=True, timeout=120)
print(r.stdout or r.stderr)
