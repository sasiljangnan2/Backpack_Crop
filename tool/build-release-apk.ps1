# 클라우드 서버(HTTPS)에 붙는 출시용 APK를 만든다. 다른 사람에게 파일로 나눠 줄 때 쓴다 (docs/deploy-cloud.md).
#
#   powershell -ExecutionPolicy Bypass -File tool\build-release-apk.ps1 -ApiBaseUrl https://backpack-xxxx.duckdns.org
#   (구글 지도를 쓰려면 -GoogleMapsKey <안드로이드 키> 를 더한다. 없으면 OpenStreetMap 지도, docs/google-maps.md)
#
# 서명 키(android/upload-keystore.jks + android/key.properties)가 없으면 처음 한 번 만든다.
# 이 키를 잃어버리면 이미 설치한 사람이 앱을 업데이트할 수 없다. 두 파일을 따로 백업해 둔다 (저장소에는 올리지 않는다).
param(
    [Parameter(Mandatory)][string]$ApiBaseUrl,
    [string]$GoogleMapsKey = ''
)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
Set-Location $root

if ($ApiBaseUrl -notmatch '^https://') {
    throw '출시용 APK에는 https:// 주소만 넣을 수 있어요 (출시 빌드는 http 접속을 막습니다).'
}
$ApiBaseUrl = $ApiBaseUrl.TrimEnd('/')

$props = 'android\key.properties'
if (-not (Test-Path $props)) {
    # keytool은 JDK에 들어 있다 (backend/scripts/run-local-windows.ps1과 같은 순서로 찾는다)
    $jdk = @($env:JAVA_HOME, "$HOME\bptools\jdk-21.0.12.1+1") +
        (Get-ChildItem 'C:\Program Files\Eclipse Adoptium', 'C:\Program Files\Java' -Directory -Filter 'jdk-*' -ErrorAction SilentlyContinue).FullName |
        Where-Object { $_ -and (Test-Path "$_\bin\keytool.exe") } |
        Select-Object -First 1
    if (-not $jdk) { throw 'keytool을 찾지 못했어요. JDK를 설치하거나 JAVA_HOME을 정해 주세요.' }
    if (Test-Path android\upload-keystore.jks) {
        throw 'android\upload-keystore.jks는 있는데 key.properties가 없어요. 백업해 둔 key.properties를 android\에 넣어 주세요.'
    }
    # PKCS12 키 저장소는 저장소 비밀번호와 키 비밀번호가 같아야 한다
    $pw = -join ((48..57) + (65..90) + (97..122) | Get-Random -Count 32 | ForEach-Object { [char]$_ })
    & "$jdk\bin\keytool.exe" -genkeypair -keystore android\upload-keystore.jks -storetype PKCS12 `
        -alias upload -keyalg RSA -keysize 2048 -validity 10000 `
        -dname 'CN=Backpack, O=Backpack Corp, C=KR' -storepass $pw -keypass $pw
    if ($LASTEXITCODE -ne 0) { throw '서명 키를 만들지 못했어요.' }
    @('storeFile=../upload-keystore.jks', "storePassword=$pw", 'keyAlias=upload', "keyPassword=$pw") |
        Set-Content -Encoding ascii $props
    Write-Host '서명 키를 만들었어요: android\upload-keystore.jks, android\key.properties (둘 다 따로 백업해 두세요)'
}

Write-Host "== 출시용 APK 빌드 (서버 $ApiBaseUrl)"
$ErrorActionPreference = 'Continue'
$defines = @("--dart-define=API_BASE_URL=$ApiBaseUrl")
if ($GoogleMapsKey) { $defines += "--dart-define=GOOGLE_MAPS_API_KEY=$GoogleMapsKey" }
flutter build apk --release @defines
if ($LASTEXITCODE -ne 0) { throw 'APK 빌드에 실패했어요.' }
$ErrorActionPreference = 'Stop'

$out = Join-Path $root 'Backpack_배포용.apk'
Copy-Item build\app\outputs\flutter-apk\app-release.apk $out -Force
Write-Host "완성: $out"
Write-Host '이 파일을 카카오톡 · 드라이브로 보내면 받는 사람이 설치할 수 있어요.'
