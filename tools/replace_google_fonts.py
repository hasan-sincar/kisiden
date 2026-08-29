from pathlib import Path

root = Path('lib')
files = list(root.rglob('*.dart'))
changed = []

for path in files:
    text = path.read_text(encoding='utf-8')
    new_text = text.replace("import 'package:google_fonts/google_fonts.dart';", "import 'package:appim/utils/local_fonts.dart';")
    new_text = new_text.replace('GoogleFonts.poppinsTextTheme(', 'LocalFonts.poppinsTextTheme(')
    new_text = new_text.replace('GoogleFonts.poppins(', 'LocalFonts.poppins(')
    if new_text != text:
        path.write_text(new_text, encoding='utf-8')
        changed.append(str(path))

print(f'changed={len(changed)}')
for item in changed:
    print(item)
