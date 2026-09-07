param(
    [Parameter(Mandatory = $true)]
    [string]$Serial,
    [string]$Adb = "$env:LOCALAPPDATA\Android\sdk\platform-tools\adb.exe"
)

$ErrorActionPreference = 'Stop'
# 테스트 전용 에뮬레이터에서만 실행하며 실제 휴대폰은 거부한다.
if ($Serial -notmatch '^emulator-\d+$') {
    throw '테스트 전용 Android 에뮬레이터의 일련번호를 지정하세요.'
}

$script = @'
set -e
content delete --uri content://com.android.contacts/raw_contacts --where "account_name='tagged_contact_test'"
content insert --uri content://com.android.contacts/raw_contacts --bind account_name:s:tagged_contact_test --bind account_type:s:tagged_contact_test
raw_id=$(content query --uri content://com.android.contacts/raw_contacts --projection _id --where "account_name='tagged_contact_test'" | sed -n 's/.*_id=\([0-9]*\).*/\1/p' | tail -n 1)
test -n "$raw_id"
content insert --uri content://com.android.contacts/data --bind raw_contact_id:i:$raw_id --bind mimetype:s:vnd.android.cursor.item/name --bind data1:s:김태그
content insert --uri content://com.android.contacts/data --bind raw_contact_id:i:$raw_id --bind mimetype:s:vnd.android.cursor.item/phone_v2 --bind data1:s:01090000001 --bind data2:i:2
content delete --uri content://call_log/calls --where "number IN ('01090000001', '+82 10-9000-0001', '01090000002')"
now_ms=$(($(date +%s) * 1000))
i=0
while [ $i -lt 105 ]; do
  if [ $((i % 2)) -eq 0 ]; then number='01090000001'; else number='+82 10-9000-0001'; fi
  content insert --uri content://call_log/calls --bind number:s:"$number" --bind type:i:1 --bind date:l:$((now_ms - i * 60000)) --bind duration:l:125 --bind presentation:i:1
  i=$((i + 1))
done
content insert --uri content://call_log/calls --bind number:s:01090000002 --bind type:i:3 --bind date:l:$((now_ms + 1000)) --bind duration:l:0 --bind presentation:i:1
content delete --uri content://sms --where "address='+82 10-9000-0001'"
content insert --uri content://sms/inbox --bind address:s:'+82 10-9000-0001' --bind body:s:'검증 문자 - 내일 산책 모임에서 만나요.' --bind date:l:$now_ms --bind read:i:1
'@

$temporaryScript = New-TemporaryFile
try {
    [System.IO.File]::WriteAllText($temporaryScript.FullName, $script.Replace("`r`n", "`n"), [System.Text.UTF8Encoding]::new($false))
    & $Adb -s $Serial push $temporaryScript.FullName /data/local/tmp/tagged_contact_test.sh
    if ($LASTEXITCODE -ne 0) { throw '테스트 스크립트를 복사하지 못했습니다.' }
    & $Adb -s $Serial shell sh /data/local/tmp/tagged_contact_test.sh
    if ($LASTEXITCODE -ne 0) { throw '테스트 데이터를 준비하지 못했습니다.' }
    foreach ($permission in @('READ_CONTACTS', 'READ_CALL_LOG', 'READ_SMS')) {
        & $Adb -s $Serial shell pm grant com.contact.tagged.tagged_contact "android.permission.$permission"
        if ($LASTEXITCODE -ne 0) { throw '테스트 권한을 허용하지 못했습니다.' }
    }
} finally {
    Remove-Item -LiteralPath $temporaryScript.FullName
}
