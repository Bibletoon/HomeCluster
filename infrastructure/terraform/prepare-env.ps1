param(
    [string]$SopsFile = ".\secrets.enc.yaml"
)

if (-Not (Test-Path $SopsFile)) {
    Write-Error "Файл SOPS '$SopsFile' не найден."
    exit 1
}

$sopsContent = sops -d --output-type json $SopsFile | ConvertFrom-Json

$awsAccessKey = $sopsContent.s3.access_key
$awsSecretKey = $sopsContent.s3.secret_key

if (-Not $awsAccessKey -or -Not $awsSecretKey) {
    Write-Error "Не удалось найти aws.access_key или aws.secret_key в файле SOPS."
    exit 1
}

[System.Environment]::SetEnvironmentVariable("TF_VAR_S3_ACCESS_KEY", $awsAccessKey, "Process")
[System.Environment]::SetEnvironmentVariable("TF_VAR_S3_SECRET_KEY", $awsSecretKey, "Process")

Write-Host "Переменные окружения AWS_ACCESS_KEY_ID и AWS_SECRET_ACCESS_KEY установлены."
