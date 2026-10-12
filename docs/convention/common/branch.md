# Branch Convention

## 브랜치는 두 종류뿐

| 브랜치 | 설명 |
|---|---|
| `main` | 항상 동작하는 코드. **직접 push 금지**, PR로만 합친다 |
| 작업 브랜치 | `main`에서 만들고, 작업이 끝나면 PR로 `main`에 합친 뒤 삭제한다 |

`develop` 브랜치는 쓰지 않는다.

## 작업 브랜치 이름

```
타입/짧은-설명
```

- 타입은 [커밋 타입](git-commit.md)과 같다: `feat`, `fix`, `docs`, `refactor`, `test`, `chore`
- 설명은 **영어 소문자 + 하이픈(-)**: `feat/trip-create`, `fix/settlement-amount`, `docs/convention`

## 작업 순서 (이것만 따라 하면 됩니다)

**1. 최신 `main`에서 브랜치 만들기**

```bash
git switch main
git pull
git switch -c feat/trip-create
```

**2. 작업하고 커밋하기** (여러 번 해도 됨)

```bash
git status          # 올릴 파일이 맞는지 확인
git add .
git commit -m "feat: 여행 생성 기능 추가"
```

**3. GitHub에 올리기**

```bash
git push -u origin feat/trip-create
```

**4. GitHub에서 PR 만들기**
- push하면 레포 페이지 위에 **Compare & pull request** 버튼이 뜬다. 눌러서 양식을 채운다.
- PR 제목은 커밋 메시지 형식과 같다: `feat: 여행 생성 기능 추가`

**5. 리뷰 받고 합치기**
- 승인되면 **Squash and merge**로 합친다.
- 합친 뒤 **Delete branch** 버튼으로 브랜치를 지운다.

**6. 다음 작업은 다시 1번부터**

## 자주 겪는 상황

- **PR을 올린 뒤 수정 요청을 받았다** → 같은 브랜치에서 고치고 커밋한 뒤 `git push`만 하면 PR에 자동으로 반영된다.
- **`main`에 실수로 커밋했다** → push하지 말고 팀원에게 물어본다. (`main` 보호 설정을 켜 두면 push 자체가 거절된다.)
- **충돌(conflict)이 났다** → 혼자 해결하기 어려우면 PR에 댓글로 도움을 요청한다.
