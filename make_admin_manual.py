# -*- coding: utf-8 -*-
# 관리자용 사용설명서 생성 (v2.7.18 기준, 2026-07)
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
_set_font(p.add_run('관리자 전용  |  2026년 7월  |  시스템 v2.7.18 기준'), 11, color=GRAY)
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

# ═══ 3. 휴지통 ═══
heading1('3. 휴지통 — 삭제된 하자 복구·영구삭제 (관리자 탭)')
body('v2.7.11부터 하자 삭제는 직원도 가능합니다. 실수·오남용에 대비해 삭제는 즉시 완전 삭제가 아니라 소프트 삭제(휴지통 이동) 방식으로 바뀌었습니다.')
heading2('3-1. 동작 방식')
bullet('직원·관리자가 하자를 삭제하면 실제 행은 지워지지 않고 deleted_at(삭제 시각)만 기록됩니다. 하자 목록·통계·KPI 어디에도 더는 집계되지 않습니다.')
bullet('연결된 사용 부속·상태이력·코멘트는 전혀 건드리지 않고 그대로 보존됩니다 — 복구 시 원상태로 완전히 되살아납니다.')
heading2('3-2. 복구')
bullet('관리자 탭 → 휴지통 탭에서 삭제된 하자 목록(객실·하자내용·등록일·삭제일시·삭제자)을 확인합니다.')
bullet('"복구" 버튼을 누르면 deleted_at이 지워지고 즉시 일반 하자 목록·통계에 다시 나타납니다.')
heading2('3-3. 영구삭제')
bullet('"영구삭제" 버튼은 실제 DELETE를 실행합니다 — 연결된 부속·이력·코멘트까지 완전히 사라지며 되돌릴 수 없습니다.')
bullet('실행 전 2단계 확인창이 뜹니다. 관리자만 실행할 수 있습니다 (RLS로 강제).')
warn_box('⚠️ 휴지통은 무한 보관이 아닙니다 — 별도의 자동 삭제/보관기간 정책은 아직 없으므로, 오래된 항목은 주기적으로 검토해 영구삭제하거나 그대로 두어도 무방합니다 (통계에는 영향 없음).')
info_box('💡 직원이 삭제 버튼을 누르는 시점에 이미 "삭제해도 휴지통에서 복구 가능"이라는 안내가 뜨므로, 직원에게 별도 설명 없이도 안심하고 삭제 기능을 쓸 수 있습니다.')

# ═══ 4. 수정이력 ═══
heading1('4. 수정이력 — 감사 로그 (관리자 탭)')
bullet('하자뿐 아니라 부품·입출고·객실·업체·설정 등 주요 데이터 전체의 등록/수정/삭제가 자동 기록됩니다.')
bullet('누가(이메일), 언제, 어떤 항목을, 무엇에서 무엇으로 바꿨는지 확인할 수 있습니다.')
bullet('액션·테이블·이메일로 필터링해 조회합니다.')
bullet('운영 데이터 초기화 실행도 실행자·일시·사유와 함께 "⚠️ 초기화"로 기록되며, 이 기록은 초기화해도 지워지지 않습니다.')

# ═══ 5. 데이터 백업 ═══
heading1('5. 데이터 백업 (관리자 탭 → 연결설정)')
bullet('"전체 백업 다운로드 (JSON)" 버튼 하나로 전체 데이터(22개 테이블)를 파일로 내려받습니다.')
bullet('주 1회, 그리고 데이터 초기화 전에는 반드시 백업을 받아 보관하세요.')
bullet('백업 파일에는 업체 계좌정보 등 민감 데이터가 포함되므로 공유 폴더에 두지 마세요.')

# ═══ 6. 하자 사진 · Storage 용량 관리 ═══
heading1('6. 하자 사진 · Storage 용량 관리')
body('v2.7.14부터 하자 상세보기에서 사진을 첨부할 수 있습니다. Supabase 무료 플랜은 스토리지 1GB, 월 다운로드(egress) 5GB로 제한되어 있어 용량 관리가 필요합니다.')
heading2('6-1. 용량을 아끼기 위해 이미 적용된 조치')
bullet('업로드 전 브라우저에서 자동으로 리사이즈(최대 1600px)·JPEG 압축(품질 75%) 후 저장 — 원본은 저장되지 않습니다.')
bullet('하자 1건당 최대 5장으로 앱에서 제한됩니다.')
bullet('사진 저장 버킷(defect-photos)은 비공개이며, 조회 시 10분 유효 서명 URL로만 접근 가능합니다.')
heading2('6-2. 하자를 지워도 사진 파일이 자동으로 안 지워지던 문제')
warn_box('⚠️ 하자 삭제(휴지통 이동)만으로는 사진 파일이 지워지지 않습니다 — 복구를 위해 의도된 동작입니다. 하지만 "휴지통에서 영구삭제"와 "운영 데이터 초기화"는 실제로 사진 파일까지 Storage에서 완전히 제거하도록 v2.7.14에서 처리했습니다.')
bullet('영구삭제·초기화 시 앱이 defect_photos 테이블에서 파일 경로를 먼저 확보한 뒤 Storage에서 삭제합니다. 두 기능 모두 반드시 새 버전의 index.html로 실행해야 정상 동작합니다 — 구버전으로 실행하면 사진 파일이 고아 상태로 남아 용량을 계속 차지합니다.')
heading2('6-3. 앱 안에서 사진 용량 확인하기 (v2.7.18)')
bullet('관리자 탭 → 연결설정 → "하자 사진 저장용량" 카드에서 "🔄 지금 조회" 버튼을 누르면, defect-photos 버킷에 실제 저장된 사진 개수와 총 용량(MB)을 무료 플랜 1GB 대비 비율로 보여줍니다.')
bullet('70% 이상이면 막대가 주황색, 90% 이상이면 빨간색으로 바뀌어 경고합니다.')
warn_box('⚠️ 이 수치는 defect-photos 버킷 하나만 집계한 것으로, Supabase 대시보드에 나오는 "프로젝트 전체 사용량"(데이터베이스 + 모든 버킷 합산)과는 다른 숫자입니다. Supabase가 프로젝트 전체 사용량을 조회하는 공개 API를 인증키만으로 제공하지 않아, 이 앱(백엔드 서버 없이 정적 페이지로 동작)에서는 전체 사용량을 안전하게 실시간 연동할 방법이 없습니다. 정확한 전체 사용량은 아래 6-4 방법을 쓰세요.')
bullet('자동으로 갱신되지 않으며, 버튼을 누른 시점의 값만 보여줍니다(실시간 스트리밍 아님).')
heading2('6-4. 정확한 전체 사용량(Supabase 대시보드)')
bullet('Supabase 대시보드 → Project Settings → Usage에서 데이터베이스·Storage·대역폭을 포함한 프로젝트 전체 사용량을 확인할 수 있습니다. 이게 가장 정확한 기준입니다.')
bullet('1GB에 근접하면: 오래된 완료 하자의 사진을 검토 후 개별 삭제하거나, Pro 플랜($25/월, 스토리지 100GB)으로 업그레이드를 검토하세요.')
info_box('💡 정확한 최신 요금제는 시점에 따라 바뀔 수 있으므로, 실제 업그레이드 전에는 supabase.com/pricing에서 현재 가격을 다시 확인하세요. 앱 안에 전체 사용량을 실시간으로 띄우고 싶다면, Supabase Management API 토큰을 안전하게 보관할 별도 서버(Edge Function 등)를 두는 방식으로 추가 개발이 가능합니다 — 필요 시 요청하세요.')

# ═══ 7. 초기화 ═══
heading1('7. 운영 데이터 초기화 (관리자 탭)')
body('시범운영 종료 등으로 하자·입출고 데이터를 전부 비울 때 사용하는 기능입니다.')
bullet('절차: 확인 문구("데이터 초기화") 입력 → 초기화 사유 입력(필수) → 실행')
bullet('삭제 대상: 하자·이력·코멘트·사진(파일 포함)·입출고·조정·공지 (재고 수량도 0으로)')
bullet('보존 대상: 계정, 기준정보(객실·타입·부위·부품·직원·업체), 수정이력(감사 로그)')
warn_box('⚠️ 실행 전 반드시 백업을 먼저 받으세요. 초기화는 되돌릴 수 없습니다. (백업 JSON에는 사진 원본 파일은 포함되지 않고 파일 경로만 기록됩니다 — 사진 자체를 보존하려면 초기화 전에 개별 다운로드가 필요합니다.)')

# ═══ 8. 재고 정정 규칙 ═══
heading1('8. 재고 정정 운영 규칙')
make_table(['상황','올바른 처리','누가'], [
    ['실물과 시스템 수량이 다름','재고 실사/조정 탭에서 실사값 입력 (전/후·차이·실사자 기록됨)','직원 가능'],
    ['입고·출고를 잘못 등록함','관리자 탭 → 재고이력에서 해당 건 삭제 → 재고 수량 자동 원복','관리자만'],
    ['재고보다 많은 출고 시도','시스템이 자동 차단 ("재고 부족" 안내)','—'],
], [4.5,9,2.9])
bullet('이미 사용된 입고분은 삭제가 차단됩니다 — 이 경우 조정으로 수량을 맞추세요.')
bullet('입고·출고·조정 내역은 입출고 등록 화면의 "최근 입출고 이력"과 관리자 탭 재고이력에서 함께 확인됩니다.')
bullet('입고자·출고자·실사자는 로그인한 본인이 자동 선택되며, 대리 입력 시 드롭다운에서 변경합니다.')

# ═══ 9. 기준정보 권한 ═══
heading1('9. 기준정보 관리 권한')
bullet('객실·객실타입·하자부위·수리부속·발주기준의 등록과 수정은 직원도 가능합니다.')
bullet('삭제는 관리자만 가능합니다 (실수로 인한 데이터 소실 방지).')
bullet('직원 명단과 외주업체 정보(계좌·서류 포함)는 관리자만 등록·수정·삭제할 수 있습니다.')
bullet('업체 서류(사업자등록증·계좌사본·계약서)는 로그인한 사용자만 열람 가능하며, 열람 링크는 10분간만 유효합니다.')

# ═══ 10. 화면 활용 팁 ═══
heading1('10. 화면 활용 팁 (v2.0~v2.7 변경점)')
make_table(['기능','사용법'], [
    ['대시보드 바로가기','미완료·긴급 카드를 클릭하면 필터된 하자 목록으로 이동'],
    ['통합 검색','하자 목록 검색창 하나로 객실·증상·부위·내용·담당자·업체 검색'],
    ['미완료 전체 필터','상태 필터에서 "미완료 전체" 선택 시 완료 제외 전체 표시'],
    ['모바일 홈','조치 필요(긴급·기한초과) 목록, 내 하자, 입출고 등록 지원'],
    ['홈 화면 추가','모바일 하단 배너 안내에 따라 홈 화면에 앱처럼 설치 가능'],
    ['업데이트 로그','연결설정 하단에서 버전별 변경 내역 확인'],
    ['하자증상 기준정보','기준정보 탭에서 하자증상 목록을 직접 추가/수정 가능 (삭제는 관리자만)'],
    ['외주업체 선택 모달','하자 등록 시 외주업체명을 자유 입력 대신 등록된 업체 중 선택'],
    ['방막 캘린더 입력','방막 기간을 시작~종료일로 입력, 종료일 없으면 진행중으로 자동 일수 증가'],
    ['하자 삭제 + 휴지통','직원도 삭제 가능(소프트 삭제), 관리자가 휴지통에서 복구/영구삭제 (3장 참조)'],
    ['하자 사진 첨부','상세보기에서 최대 5장, 자동 압축 후 저장 (6장 참조)'],
], [4,12.4])

# ═══ 11. FAQ ═══
heading1('11. 관리자 FAQ')
faqs = [
    ('직원이 "저장이 안 된다"고 합니다.',
     '화면에 "권한이 없습니다" 안내가 떴는지 확인하세요. 떴다면 권한 설계상 정상입니다(예: 직원의 기준정보 삭제). 안내 없이 저장이 안 되면 화면 캡처와 함께 보고받아 주세요.'),
    ('권한을 바꿨는데 적용이 안 됩니다.', '대상자가 로그아웃 후 재로그인해야 새 권한이 적용됩니다.'),
    ('초대 메일이 발송되지 않습니다.', 'SMTP(메일 발송) 설정 문제일 수 있습니다. Supabase 대시보드의 SMTP 설정에서 앱 비밀번호가 유효한지 확인하세요.'),
    ('실수로 데이터를 지웠습니다.', '최근 백업 JSON이 복구 근거가 됩니다. 수정이력(감사 로그)에서 누가 언제 지웠는지 먼저 확인하세요.'),
    ('재고 숫자가 이상합니다.', '관리자 탭 재고이력에서 해당 부품의 입출고·조정 흐름을 확인하고, 실물과 다르면 재고 실사/조정으로 맞추세요.'),
    ('비밀번호 규칙이 뭔가요.', '8자 이상, 영문과 숫자를 모두 포함해야 합니다. 특수문자는 자유롭게 추가할 수 있습니다.'),
    ('직원이 하자를 잘못 삭제했습니다.', '관리자 탭 → 휴지통에서 해당 건을 찾아 "복구" 버튼을 누르세요. 부속·이력·코멘트까지 그대로 되살아납니다.'),
    ('휴지통과 데이터 초기화(7장)는 어떻게 다른가요.', '휴지통은 개별 하자 단위의 실수 복구용입니다. 초기화는 하자·이력 등 운영 데이터 전체를 한 번에 비우는 별개 기능이며, 초기화되면 휴지통에 있던 항목도 함께 사라지고 복구할 수 없습니다.'),
    ('Storage 용량이 다 찼다는 안내를 받았습니다.', 'Supabase 대시보드 Usage에서 실사용량을 확인하세요. 오래된 완료 하자의 사진을 정리하거나, 지속적으로 부족하면 Pro 플랜 업그레이드를 검토하세요 (6장 참조).'),
]
for q,a in faqs:
    p = doc.add_paragraph(); p.paragraph_format.space_before = Pt(8); p.paragraph_format.space_after = Pt(2)
    _set_font(p.add_run('Q. '+q), 10.5, True, BLUE)
    body(a, size=10)

p = doc.add_paragraph(); p.alignment = WD_ALIGN_PARAGRAPH.CENTER; p.paragraph_format.space_before = Pt(24)
_set_font(p.add_run('시흥 웨이브파크 하자관리 시스템  |  문의: 관리자 (mac.lee@handys.co.kr)  |  v2.7.18 · 2026-07'), 9, color=GRAY)

here = os.path.dirname(os.path.abspath(__file__))
docx_path = os.path.join(here, '하자관리시스템_관리자용_사용설명서.docx')
doc.save(docx_path)
print('docx:', docx_path)
r = subprocess.run(['soffice','--headless','--convert-to','pdf','--outdir',here,docx_path],
                   capture_output=True, text=True, timeout=120)
print(r.stdout or r.stderr)
