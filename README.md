# 승상 할일판

분류별로 접고 펴는 개인 할일판. 정적 페이지 하나로 되어 있고 GitHub Pages에서 바로 연다.

- 주소: https://iseungsang01.github.io/todo-board/
- 저장: Supabase. 화면에서 이메일·비밀번호로 회원가입하면 바로 로그인되고(메일 인증 꺼 둠), 로그인하면 어느 기기에서든 같은 목록이 보이고, 다른 기기에서 바꾼 것은 바로 따라온다. **내보내기**/**가져오기**는 JSON 백업용.
- 휴대폰에서는 Chrome 메뉴의 "홈 화면에 추가"로 앱처럼 띄울 수 있다.

## 쓰는 법

- 할 일은 분류 묶음 맨 아래 칸에, 분류는 목록 맨 아래 "+ 분류 추가"로 적는다. 분류 이름은 ✎로 바꾼다.
- 할 일 글에 `11/12`, `내일`, `다음주 금`, `D-3` 같은 말을 넣으면 마감일로 빠진다.
- 제목 옆 `+`로 하위 항목(메모)을 5단계까지 단다.
- 여러 줄을 한 번에 붙여 넣으면 줄마다 하나씩 들어간다.
- 3일 안 마감, 지난 것, ★ 표시한 것은 맨 위 "급한 일"에 모인다.
- 분류 묶음의 색 점을 누르면 색이 바뀌고, ⠿ 손잡이를 끌면 순서가 바뀐다.
- 터치 화면에서는 한 줄을 오른쪽으로 밀면 완료, 왼쪽으로 밀면 삭제.

## 개발

빌드 없음. `index.html`을 고치고 `main`에 푸시하면 Pages가 그대로 서빙한다.

### Supabase

- planner 프로젝트(`gznuqhjenzeucpmonesl`)를 같이 쓴다. 할일판 데이터는 `todo_board_docs` 표 하나에만 있고, 로그인 사용자만 planner와 공유한다.
- 표·정책은 `schema.sql`. 새로 만들 때는 SQL Editor에서 실행한다.
- Authentication → URL Configuration의 Redirect URLs에 `https://iseungsang01.github.io/todo-board/`와 `http://localhost:8765/`가 들어 있다. Site URL은 planner용이라 건드리지 않는다.
- `index.html`의 anon key는 공개용이라 커밋해도 된다(데이터는 RLS로 본인 것만 보인다).

예전 localStorage 판에서 쓰던 할 일은 처음 로그인했을 때 서버가 비어 있으면 자동으로 올라간다.
