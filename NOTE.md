# Note.md

## LPG

Lack of Parser and code Generator
 : parsing/code generation helper library

- `lp`: Parser helper
- `lg`: code Generator helper
- `lpath`: Path helper
- `ltup`: Lua named-tuple helper

### TODO

- `larg`: Argument parser
- `lish`: Interactive shell

#### `lp, lg``

아이디어

일단 `pcall`의 에러메세지에 처음에 `FILENAME:LINE: ...` 형태임.
만약 `load("return " .. src, chunkname)()`꼴로 실행하면
`[string "CHUNKNAME"]:LINE: ...` 형태로 나옴.
즉, 이 앞쪽만 찾아서 치환하면 에러 위치를 바꿀 수 있음.

그렇다면 생성된 루아의 위치에서 역으로 소스 위치를 저장해야 하는데,
이 소스 위치를 하나의 정수로 나타내고 싶음.
그래서 각 파일마다 적당한 offset을 주고
그 offset + linum으로 로케이션을 지정함.
예를 들어서 `a.lua`가 offset이 100에 총 200라인이면, 다음에 `b.lua`가
추가되었을 때 offset을 300으로 설정하고, `a.lua`의 1, 2, 3 ..., 200 라인은
각각 101, 102, 103, 300으로 지시 가능하고, `b.lua`의 1, 2, 3, ..., 라인은
301, 302, ...으로 지시가 가능해짐. 즉, 임의의 파일의 줄을 정수 하나로
나타낼건데 파일 이름을 SrcName, 오프셋을 SrcOff라고 하자.
그리고 소스위 위치를 나타내는 것을 SrcLoc 이라고 할건데,
만약 SrcLoc에서 파일과 위치를 알고 싶다면
`SrcOff < SrcLoc`인 가장 작은 `SrcOff`를 찾아낸 뒤,
그 `SrcOff`에 대응되는 파일이름과, `SrcLoc - SrcOff`가 줄 번호가 됨.
이 대응을 저장하는 것이 `src_loc_table`이고,
얘는 파싱하는 단계에서 생성이 되어야 하므로,
lp의 global context로 관리를 함..

- `src_loc_table`: SrcName <-> SrcOff

이 때문에 잘 해야되는 것은 lp에서 chunk가 추가되면 바로 chunk의 줄 수를
구해서 `src_loc_table`에 저장을 해야하고,
현재 위치나 마지막 위치를 `SrcLoc`으로 만드는 것을 추가해야됨.

중간에 AST를 만들면서 `SrcLoc`은 잘 저장했다고 하고
실제 생성된 루아 코드 위치랑 `SrcLoc`을 대응시켜야 하는데,
이걸 위해서 `lg`에서는 생성된 chunk의 이름과, 각 줄이 들어오면 `SrcLoc`의
어디에 해당하는지를 저장하는 table을 같이 만들어줘야함.

- `err_loc_table`: CHUNKNAME -> LINE -> SrcLoc

그런데 일단 `lg`에서 만드는 것은 하나의 `chunk`만이므로,
line과 srcloc을 대응시키는 테이블을 내뱉어야 한다.
그리고 `lg`에서 생성을 할 때, 기존처럼 문자열을 concat 하는 것이 아니라
각 줄을 저장하는 table을 만들어서, 해당 테이블에 줄을 추가하면 `SrcLoc`도
추가하게 하고, 이후에 문자열을 `\n`넣고 조인,
`SrcLoc`은 따로 `err_loc_table`에 넣도록 한다.

근데 문제는 이 두 테이블은 다 함수나 key-value로 저장하면 용량을 많이 차지하는
문제가 있어서, `binary search`를 하도록 만드는게 낫다.

- `src_loc_table`: 홀수번째에 SrcOff, 짝수번째에 `SrcName`을 넣고, `SrcOff`로
정렬. 파일 이름으로 찾는 경우는 사실상 없으므로. 보통은 `SrcOff`로 찾는데,
이 때 이분탐색
- `err_loc_table[filename]`: 홀수번째에 생성된 코드에서 시작하는 줄 번호,
짝수번째에 그 줄 번호부터 해당하는 `SrcLoc`.
이 경우도 마찬가지로 `SrcLoc`에서 찾는 경우는 없으며, 홀수번째로 정렬하고
이분탐색, 만약 연속된 줄이 같은 `SrcLoc`인 경우에 이를 어느 정도
생략할 수 있음.

추가적으로 생성되는 코드는 `function() ... end`로 감싸지게 하고,
만약 인터프리팅을 한다면 `return`을 앞에 붙여서 load하도록 하고,
컴파일을 한다면 `F = `을 앞에 붙여 변수에 저장하도록 함.
그리고 컨텍스트 생성 등은 이후 라인에서 하거나, 아예 별개의 청크에서 실행.

전역 컨텍스트는 글로벌 `_C`, 에러테이블 `_E`, 소스테이블 `_S`가 있어야하고,
저기서 생성된 코드는 `handled_call(f, _E, _S)` 처럼 에러 메시지를
다른 것으로 바꾸는 함수에 넣고 실행해야 함.

## LNG

Language which is Not Good
 : Simple PL compiled into Lua

## Examples

- `bf`: Brainfuck-to-Lua compiler to test LPG
