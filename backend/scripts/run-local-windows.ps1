# Docker 없이 Windows에서 로컬 서버를 띄운다.
#   MySQL: PC에 설치한 MySQL 8 (backpack DB · backpack 계정, backend/README.md 참고)
#   Redis: WSL Ubuntu의 redis-server (sudo apt install redis-server)
#
#   cd backend
#   powershell -ExecutionPolicy Bypass -File scripts\run-local-windows.ps1
#
# WSL은 Windows의 localhost로 포트를 넘겨 주지 않는 PC가 있어서, Redis를 WSL 주소에 비밀번호를 걸고 연다.
# WSL 주소는 재부팅하면 바뀔 수 있으므로 실행할 때마다 다시 찾는다. 창을 닫으면 Redis와 서버가 함께 꺼진다.
param(
    [int]$RedisPort = 6380,
    [int]$ServerPort = 8080,
    [string]$Distro = 'Ubuntu'
)
$ErrorActionPreference = 'Stop'
$backend = Split-Path $PSScriptRoot -Parent
Set-Location $backend

if (-not (Test-Path .env)) {
    Copy-Item .env.example .env
    Write-Host '.env.example을 복사해 .env를 만들었어요. MySQL 계정이 다르면 .env의 DB_ 값을 고쳐 주세요.'
}

# JDK 21 (build.gradle.kts의 toolchain). JAVA_HOME이 21이 아니면 흔한 설치 위치에서 찾는다
$jdk = @($env:JAVA_HOME, "$HOME\bptools\jdk-21.0.12.1+1") +
    (Get-ChildItem 'C:\Program Files\Eclipse Adoptium', 'C:\Program Files\Java' -Directory -Filter 'jdk-21*' -ErrorAction SilentlyContinue).FullName |
    Where-Object { $_ -and (Test-Path "$_\release") -and ((Get-Content "$_\release" -Raw) -match 'JAVA_VERSION="21') } |
    Select-Object -First 1
if (-not $jdk) { throw 'JDK 21을 찾지 못했어요. Temurin 21을 설치하거나 JAVA_HOME을 JDK 21로 정해 주세요.' }
$env:JAVA_HOME = $jdk

# @(): 주소가 하나뿐이어도 배열로 받아 [0]이 첫 글자가 되지 않게 한다
$wslIp = @((wsl -d $Distro -- hostname -I) -split '\s+' | Where-Object { $_ })[0]
if (-not $wslIp) { throw "WSL($Distro) 주소를 찾지 못했어요. wsl -l -v 로 배포판 이름을 확인해 주세요." }

# 이 PC에서만 쓰는 Redis 비밀번호. 처음 한 번 만들어 backend/.redis_password에 둔다 (.gitignore)
$pwFile = Join-Path $backend '.redis_password'
if (-not (Test-Path $pwFile)) {
    -join ((48..57) + (65..90) + (97..122) | Get-Random -Count 32 | ForEach-Object { [char]$_ }) |
        Set-Content -NoNewline -Encoding ascii $pwFile
}
$redisPw = (Get-Content $pwFile -Raw).Trim()

Write-Host "Redis: $wslIp`:$RedisPort (WSL $Distro)"
# 지난번에 창을 그냥 닫아 남은 Redis가 있으면 먼저 끈다
wsl -d $Distro -u root -- pkill -f "redis-server .*:$RedisPort"
$redis = Start-Process wsl -PassThru -WindowStyle Minimized -ArgumentList @(
    '-d', $Distro, '-u', 'root', '--', 'redis-server', '--port', "$RedisPort",
    '--bind', '127.0.0.1', $wslIp, '--requirepass', $redisPw, '--dir', '/tmp', '--appendonly', 'no')

# Gradle은 경고를 stderr로 쓴다. 그걸 오류로 보고 멈추지 않게 한다
$ErrorActionPreference = 'Continue'
try {
    $env:SPRING_PROFILES_ACTIVE = 'dev'
    $env:REDIS_HOST = $wslIp
    $env:REDIS_PORT = "$RedisPort"
    $env:REDIS_PASSWORD = $redisPw
    Write-Host "서버: http://localhost:$ServerPort (멈추려면 Ctrl+C)"
    & .\gradlew.bat bootRun "--args=--server.port=$ServerPort"
}
finally {
    # wsl.exe만 끄면 리눅스 쪽 redis-server가 남을 수 있어 직접 끈다
    wsl -d $Distro -u root -- pkill -f "redis-server .*:$RedisPort"
    if ($redis -and -not $redis.HasExited) { Stop-Process -Id $redis.Id -Force }
}
