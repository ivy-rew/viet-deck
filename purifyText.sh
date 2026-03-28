#`/bin/bash

if [ $# -ne 1 ]; then
  echo "Usage: $0 <slides_folder>"
  exit 2
fi

slides="$1"

prompt="$(cat <<EOF
1. Read all txt files in the ${slides}/scene_text directory\n
2. Fix Vietnamese character issues/spelling mistakes in the text\n
3. Extract the content into a CSV file with the format:\n
word_vn; word_en; synonyms (optional); usage1_vn; usage1_en; usage2_vn; usage2_en; audio; picture;\n
4. Write the CSV file into $PWD/${slides}.csv\n\n
hints: \n
- the audio is just a reference to the corresponding .mp3 file in the ${slides}/scene_audio/ directory.\n 
- the picture is a reference to the corresponding .jpg picture file in the ${slides}/scene_picture/ directory.\n
- when multiple picture crops exist for the same slide (for example basename_01.jpg, basename_02.jpg), use basename_01.jpg by default.\n
- for audio use '[sound:filename.mp3]' format (include brackets!) where filename is the basename of the .mp3 file.\n
- picture should only be referred by their basename.\n
- omit the header row in the CSV file, just write the content rows.\n
EOF
)"

echo $prompt

copilot\
 -p "${prompt}"\
 --allow-tool 'write'\
 --model gpt-4.1
 #--no-ask-user\
