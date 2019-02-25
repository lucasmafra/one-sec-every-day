clear()
{
  rm -rf tmp
}

setup()
{
  mkdir -p tmp/sorted
  mkdir -p tmp/cutted
  mkdir -p tmp/ts
}

fix_dates()
{
  pattern="WhatsApp Video ([0-9]{4})-([0-9]{2})-([0-9]{2}) at ([0-9]+)\.([0-9]{2})\.([0-9]{2}) ([A-Z]{2}).mp4"
  for video in videos/*.mp4; do
    filename=$(basename "${video}")
    if [[ $filename =~ $pattern ]]; then
      year=${BASH_REMATCH[1]}
      month=${BASH_REMATCH[2]}
      day=${BASH_REMATCH[3]}
      hour=${BASH_REMATCH[4]}
      minute=${BASH_REMATCH[5]}
      second=${BASH_REMATCH[6]}
      am_pm=${BASH_REMATCH[7]}
      if [ $am_pm == "AM" ] && [ $hour == "12" ]; then
        hour="23"
        minute="59"
        second="59"
        day=$((day-1))
      fi
      cp "${video}" "tmp/sorted/${year}_${month}_${day}_${hour}_${minute}_${second}_${am_pm}.mp4"
    else
      echo "DOES NOT MATCH $filename"
      exit 1;
    fi
  done   
}

cut_videos()
{
  echo "Cutting all videos to 1 second...\n"
  for video in tmp/sorted/*.mp4; do
    filename=$(basename "${video}")
    ffmpeg -i "${video}" -ss 00:00:00 -t 00:00:01 -async 1 -strict -2 "tmp/cutted/${filename}" >/dev/null 2>&1
  done
}

generate_ts()
{
  echo "Generating intermediary format...\n"
  for video in tmp/cutted/*.mp4; do
    filename=$(basename "${video}")
    filename="${filename%.*}" # get rid of extension
    filename="${filename}.ts" # add .ts extension
    ffmpeg -i "${video}" -c copy -bsf:v h264_mp4toannexb -f mpegts "tmp/ts/${filename}" >/dev/null 2>&1
  done
}

concat_videos()
{
  echo "Concatenating videos...\n"
  command="concat:"
  for video in tmp/ts/*.ts; do
    command="${command}${video}|"    
  done
  command="ffmpeg -y -i \"${command%?}\" -c copy -bsf:a aac_adtstoasc output.mp4 >/dev/null 2>&1"
  eval $command
}

main()
{
  clear
  setup
  fix_dates # adjust past midnight videos
  cut_videos # cut all videos to 1 second
  generate_ts # intermediary format for concatenation
  concat_videos
  clear
  echo "Done! :) \nCheck out the result video \"output.mp4\""
  exit 0;
}

main
