$ErrorActionPreference = 'Stop'

flutter build web --release
Copy-Item -LiteralPath 'web\support.html' -Destination 'build\web\support.html' -Force
npx -y firebase-tools@latest deploy --only hosting --project kisiden-projesi
