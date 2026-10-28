# PC에서 클라우드 VM으로 서버를 올린다. 처음 설치와 업데이트 모두 이걸로 한다 (docs/deploy-cloud.md).
#
#   cd backend
#   powershell -ExecutionPolicy Bypass -File scripts\deploy-cloud.ps1 -Server <서버 공인 IP> -Domain backpack-xxxx.duckdns.org
#
# 하는 일: 서버 jar 빌드 → deploy 폴더와 함께 서버에 복사 → 서버에서 deploy/setup-server.sh 실행.
# -Domain은 처음 한 번만 주면 서버의 .env에 남는다. 업데이트할 때는 -Server만 준다.
# 네이버 클라우드는 root + 비밀번호로 들어간다 (복사할 때 · 실행할 때 비밀번호를 두 번 묻는다).
# SSH 키로 들어가는 서버(Oracle 등)는 -Key <키 파일> -User ubuntu 를 준다.
param(
    [Parameter(Mandatory)][string]$Server,
    [string]$Key = '',
    [string]$Domain = '',
    # 네이버 클라우드 Ubuntu 서버의 관리자 계정
    [string]$User = 'root'
)
$ErrorActionPreference = 'Stop'
$backend = Split-Path $PSScriptRoot -Parent
Set-Location $backend

# ssh는 다른 사용자도 읽을 수 있는 키 파일을 거부한다. 내 계정만 읽을 수 있는 복사본을 ~/.ssh에 둔다
$keyCopy = $null
if ($Key) {
    $keyCopy = Join-Path $HOME '.ssh\backpack-cloud.key'
    New-Item -ItemType Directory -Force (Split-Path $keyCopy) | Out-Null
    if ((Resolve-Path $Key).Path -ne $keyCopy) {
        if (Test-Path $keyCopy) { Remove-Item $keyCopy -Force }
        Copy-Item $Key $keyCopy
        icacls $keyCopy /inheritance:r /grant:r "${env:USERNAME}:(F)" | Out-Null
    }
}

# JDK 21 (scripts/run-local-windows.ps1과 같은 순서로 찾는다)
$jdk = @($env:JAVA_HOME, "$HOME\bptools\jdk-21.0.12.1+1") +
    (Get-ChildItem 'C:\Program Files\Eclipse Adoptium', 'C:\Program Files\Java' -Directory -Filter 'jdk-21*' -ErrorAction SilentlyContinue).FullName |
    Where-Object { $_ -and (Test-Path "$_\release") -and ((Get-Content "$_\release" -Raw) -match 'JAVA_VERSION="21') } |
    Select-Object -First 1
if (-not $jdk) { throw 'JDK 21을 찾지 못했어요. Temurin 21을 설치하거나 JAVA_HOME을 JDK 21로 정해 주세요.' }
$env:JAVA_HOME = $jdk

Write-Host '== 서버 jar 빌드'
# Gradle은 경고를 stderr로 쓴다. 그걸 오류로 보고 멈추지 않게 하고, 종료 코드로 판단한다
$ErrorActionPreference = 'Continue'
& .\gradlew.bat bootJar
if ($LASTEXITCODE -ne 0) { throw 'jar 빌드에 실패했어요.' }
$ErrorActionPreference = 'Stop'
$jar = Get-ChildItem build\libs\*.jar | Where-Object { $_.Name -notlike '*-plain.jar' } |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1

# deploy 폴더 + app.jar를 하나로 묶는다. .env는 VM에서 만든 값을 덮지 않도록 넣지 않는다
$temp = [IO.Path]::GetTempPath()
$stage = Join-Path $temp 'backpack-deploy'
$bundle = Join-Path $temp 'backpack-deploy.tgz'
if (Test-Path $stage) { Remove-Item $stage -Recurse -Force }
New-Item -ItemType Directory $stage | Out-Null
Copy-Item deploy\* $stage -Recurse -Exclude .env
Copy-Item $jar.FullName (Join-Path $stage 'app.jar')
tar -czf $bundle -C $stage .
if ($LASTEXITCODE -ne 0) { throw '파일을 묶지 못했어요.' }

$ssh = @('-o', 'StrictHostKeyChecking=accept-new', '-o', 'ConnectTimeout=15')
if ($keyCopy) { $ssh = @('-i', $keyCopy) + $ssh }
$target = "$User@$Server"
Write-Host "== 서버($Server)로 복사"
$ErrorActionPreference = 'Continue'
scp @ssh $bundle "${target}:backpack-deploy.tgz"
if ($LASTEXITCODE -ne 0) {
    throw '서버에 접속하지 못했어요. 공인 IP, 비밀번호(또는 -Key 키 파일), 계정 이름(-User), ACG의 22번 포트를 확인해 주세요.'
}

Write-Host '== 서버에서 설치 · 시작'
$envPart = ''
if ($Domain) { $envPart = "DOMAIN=$Domain " }
# PC의 backend\.env에 있는 API 키(Gemini · 구글 지도 서버 키 · 수출입은행)를 서버 .env에도 넣는다 (SSH로 암호화돼 간다)
if (Test-Path .env) {
    # Windows PowerShell 5.1은 인코딩을 주지 않으면 UTF-8 한글 주석을 잘못 읽어 다음 줄과 붙인다
    foreach ($line in Get-Content .env -Encoding UTF8) {
        if ($line -match '^(GEMINI_API_KEY|GOOGLE_MAPS_API_KEY|EXIM_API_KEY)=([A-Za-z0-9._-]+)\s*$') {
            $envPart += "$($Matches[1])='$($Matches[2])' "
        }
    }
}
# Windows에서 고친 파일은 줄 끝이 CRLF일 수 있다. bash가 읽기 전에 LF로 바꾼다
$remote = 'mkdir -p ~/backpack && tar -xzf ~/backpack-deploy.tgz -C ~/backpack && rm ~/backpack-deploy.tgz' +
    ' && sed -i ''s/\r$//'' ~/backpack/*.sh ~/backpack/Caddyfile' +
    " && sudo ${envPart}bash ~/backpack/setup-server.sh"
ssh @ssh $target $remote
$code = $LASTEXITCODE
Remove-Item $stage -Recurse -Force
Remove-Item $bundle -Force
if ($code -ne 0) { throw '서버를 띄우지 못했어요. 위 로그를 확인해 주세요.' }
