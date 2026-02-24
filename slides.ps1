git clone --depth 1 https://github.com/cs21206-iitkgp/cs21206-iitkgp.github.io.git
$repoDir = "cs21206-iitkgp.github.io"
$spDir = Get-ChildItem -Path "$repoDir/sp*" -Directory | Select-Object -First 1

if ($spDir) {
    # Only copy folders (like Slides) to avoid picking up root yml/html files
    Get-ChildItem -Path $spDir.FullName -Directory | ForEach-Object {
        Copy-Item -Path $_.FullName -Destination "." -Recurse -Force
    }
}

# Cleanup root level yml and html files
Get-ChildItem -Path "." -File | Where-Object { $_.Extension -in @(".yml", ".html") } | Remove-Item -Force

if (Test-Path "Slides") {
    # Keep only presentation files in Slides
    Get-ChildItem -Path "Slides" -Recurse -File | Where-Object { $_.Extension -notin @(".pdf", ".ppt", ".pptx") } | Remove-Item -Force
}

Remove-Item -Path $repoDir -Recurse -Force -ErrorAction SilentlyContinue