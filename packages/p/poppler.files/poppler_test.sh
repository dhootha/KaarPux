# /bin/sh
set -o nounset
set -o errexit
echo "Testing poppler"
DIR=$(mktemp -d)
cd $DIR
cat > hello.pdf <<EOF
%PDF-1.7

1 0 obj  % entry point
<<
  /Type /Catalog
  /Pages 2 0 R
>>
endobj

2 0 obj
<<
  /Type /Pages
  /MediaBox [ 0 0 200 200 ]
  /Count 1
  /Kids [ 3 0 R ]
>>
endobj

3 0 obj
<<
  /Type /Page
  /Parent 2 0 R
  /Resources <<
    /Font <<
      /F1 4 0 R 
    >>
  >>
  /Contents 5 0 R
>>
endobj

4 0 obj
<<
  /Type /Font
  /Subtype /Type1
  /BaseFont /Times-Roman
>>
endobj

5 0 obj  % page content
<<
  /Length 44
>>
stream
BT
70 50 TD
/F1 12 Tf
(Hello, world!) Tj
ET
endstream
endobj

xref
0 6
0000000000 65535 f 
0000000010 00000 n 
0000000079 00000 n 
0000000173 00000 n 
0000000301 00000 n 
0000000380 00000 n 
trailer
<<
  /Size 6
  /Root 1 0 R
>>
startxref
492
%%EOF
EOF
/bin/pdfinfo hello.pdf | grep -F "PDF version" | grep -F "1.7"
/bin/pdftotext hello.pdf - | grep -F "Hello, world"
/bin/pdftops hello.pdf - | grep -F "Hello, world"
/bin/pdftocairo -ps hello.pdf - | grep -F "ello, wor"
cd
rm -rf $DIR
echo "Testing poppler: OK"
