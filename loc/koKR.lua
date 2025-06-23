local L = LibStub("AceLocale-3.0"):NewLocale("Breakables", "koKR", false)
if not L then return end

L["Are you sure you want to clear the ignore list?"] = "차단 목록을 정말로 초기화하시겠습니까?"
L["Are you sure you want to remove this item from the ignore list?"] = "차단 목록에서 이 항목을 정말 제거하시겠습니까?"
L["Breakables"] = "Breakables"
L["Button grow direction"] = "버튼 성장 방향"
L["Button scale"] = "버튼 크기"
L["Clear ignore list"] = "차단 목록 초기화"
L["Click to open Breakables options."] = "클릭하면 설정창을 엽니다."
L["Down"] = "아래로"
L["Font size"] = "글꼴 크기"
L["Hide bar"] = "실행 바 숨기기"
L["Hide during combat"] = "전투 중에 숨기기"
L["Hide during pet battles"] = "애완동물 대전 중 UI 비활성화"
L["Hide Eq. Mgr items"] = "세트로 설정된 아이템 숨김"
L["Hide if no breakables"] = "할 일이 없으면 숨김"
L["Hide Tabards"] = "휘장 숨김"
L["Hold shift and left-click to drag the Breakables bar around."] = "Breakables 바를 이동하려면 쉬프트 키를 누르고 왼쪽 클릭후 드레그합니다."
L["How many breakable buttons to display next to the profession button at maximum"] = "전문 기술의 스킬 버튼에 이어서 breakable 버튼을 최대 얼마만큼 표시할지를 설정합니다."
L["If checked, a lockbox that is too high level for the player to pick will still be shown in the list, otherwise it will be hidden."] = "선택하면, 플레이어가 열 수 없을 정도로 레벨이 높은 자물쇠 상자도 목록에 표시됩니다. 선택하지 않으면 목록에서 숨겨집니다."
L["Ignore Enchanting skill level"] = "마법부여 기술 레벨 무시"
L["Ignore list"] = "차단 목록"
L["Items that have been right-clicked to exclude from the breakable list. Un-check the box to remove the item from the ignore list."] = "우클릭으로 깨짐 목록에서 제외한 아이템입니다. 무시 목록에서 제거하려면 체크 해제하세요."
L["Left"] = "왼쪽"
L["Max number to display"] = "최대 개수 표시"
L["Reset"] = "초기화"
L["Reset placement"] = "위치 초기화"
L["Resets where the buttons are placed on the screen to the default location."] = "버튼 위치를 기본값으로 초기화합니다."
L["Right"] = "오른쪽"
L["Settings"] = "설정"
L["Show high-level lockboxes"] = "열 수 없는 자물쇠 상자도 표시"
L["Show soulbound items"] = "귀속 아이템 보기"
L["Show tooltip on breakables"] = "추출 아이템에 툴팁 표시"
L["Show tooltip on profession"] = "전문 기술에 툴팁 표시"
L["This controls which direction the breakable buttons grow toward."] = "이것은 breakable의 버튼이 어떤 쪽으로 성장할지 방향을 설정합니다."
L["This sets the size of the text that shows how many items you have to break."] = "이것은 아이템이 얼마만큼 있는지 표시하는 숫자의 문자 크기를 설정합니다."
L[ [=[This will add the chosen item to the ignore list so it no longer appears as breakable. Items can be removed from the ignore list in the Breakables settings.

Would you like to ignore this item?]=] ] = [=[선택한 아이템을 무시 목록에 추가하여 마력 추출 파괴 목록에서 제외합니다. 무시 목록은 설정에서 수정할 수 있습니다.

이 항목을 표시하지 않겠습니까?]=]
L["This will completely hide the breakables bar whether you have anything to break down or not. Note that you can toggle this in a macro using the /breakables command as well."] = "할 일이 있는지에 상관없이 완전히 breakables의 실행 바를 숨깁니다. 또한 /breakables 명령을 사용해 전환할 수 있습니다."
L["This will scale the size of each button up or down."] = "이것은 각 버튼의 위 또는 아래 크기를 확장합니다."
L["Up"] = "위로"
L["Welcome"] = [=[|cff33ff99Breakables|r!를 사용해 주셔서 감사합니다. 대화창에 |cffffff78/brk|r 이나 |cffffff78/breakables|r를 사용해 리스트형식의 메뉴 옵션를 열 수 있습니다.

breakables의 실행 바 이동은 전문 기술의 스킬 버튼을 시프트 키를 누르고 마우스 왼쪽 버튼을 클릭해서 드래그합니다. 그리고, 전문 기술의 스킬 버튼을 클릭하지 않고 breakable의 버튼을 직접 클릭해서 대신할 수 있습니다.

어떤 기능 요청이나 문제가 있다면, |cff33ff99breakables@parnic.com|r으로 메일을 보내주시거나 |cffffff78curse.com|r 또는 |cffffff78wowinterface.com|r을 방문해 의견을 남겨주세요.]=]
L["Whether or not items should be shown when Breakables thinks you don't have the appropriate skill level to disenchant it."] = "해당 기술 레벨이 부족해도 마법부여 가능한 아이템을 표시할지 설정합니다."
L["Whether or not to display soulbound items as breakables."] = "breakables에 귀속 아이템을 표시하려면 선택합니다."
L["Whether or not to hide items that are part of an equipment set in the game's equipment manager."] = "게임에서 장비 관리자로 설정한 장비의 아이템을 숨깁니다."
L["Whether or not to hide tabards from the disenchantable items list."] = "분해 아이템 목록에서 휘장을 숨길지 설정합니다."
L["Whether or not to hide the action bar if no breakables are present in your bags"] = "가방에 더는 breakables를 사용할 아이템이 있지 않으면 실행 바를 숨깁니다."
L["Whether or not to hide the breakables bar when you enter a pet battle."] = "애완동물 대전 중 추출 바를 표시할지 선택."
L["Whether or not to hide the breakables bar when you enter combat and show it again when leaving combat."] = "breakables 실행 바를 전투 중일 때 숨기고 끝나면 다시 표시합니다."
L["Whether or not to show an item tooltip when hovering over a breakable item button."] = "추출 아이템 버튼에 툴팁 표시 여부 설정."
L["Whether or not to show an item tooltip when hovering over a profession button on the Breakables bar."] = "Breakables 바에서 전문 기술 버튼에 마우스를 올렸을 때 아이템 툴팁 표시 여부 결정."
L["You can click on this button to break this item without having to click on the profession button first."] = "전문 기술의 스킬 버튼을 클릭하지 않고 이 버튼으로 대신할 수 있습니다."
L["You can right-click on this button to ignore this item. Items can be unignored from the options screen."] = "이 버튼을 우클릭하면 아이템을 무시합니다. 옵션 화면에서 복원할 수 있습니다."

