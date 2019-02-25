clear()
{
  rm -rf tmp
}

setup()
{
  mkdir -p tmp/backup
  mkdir -p tmp/desktop
}

backup()
{
  cp -r $1/* tmp/backup
}

fix_dates()
{
  pattern="WhatsApp Video ([0-9]{4})-([0-9]{2})-([0-9]{2}) at ([0-9]+)\.([0-9]{2})\.([0-9]{2}) ([A-Z]{2}).mp4"
  for video in tmp/backup/*.mp4; do
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
      mv "${video}" "tmp/backup/${year}_${month}_${day}_${hour}_${minute}_${second}_${am_pm}.mp4"
    else
      echo "DOES NOT MATCH $filename"
      exit 1;
    fi
  done
}

cut_videos()
{
  echo "Cutting all videos to 1 second..."
  for video in tmp/backup/*.mp4; do
    filename=$(basename "${video}")
    ffmpeg -i "${video}" -ss 00:00:00 -t 00:00:01 -async 1 -strict -2 "tmp/desktop/${filename}" >/dev/null 2>&1
  done
  backup "tmp/desktop"
}

pad_vertical_videos()
{
  echo "Padding vertical videos to fit horizontal size..."
  for video in tmp/backup/*.mp4; do
    filename=$(basename "${video}")
    width=$(ffprobe -v quiet -print_format json -show_format -show_streams "${video}" | jq -r ".streams[0].width")
    height=$(ffprobe -v quiet -print_format json -show_format -show_streams "${video}" | jq -r ".streams[0].height")
    if [ $height -gt $width ]; then
      new_height=352
      new_width=196
      ffmpeg -y -i "${video}" -vf scale=196:352,setsar=1:1 "tmp/desktop/${filename}" >/dev/null 2>&1
      ffmpeg -y -i "tmp/desktop/${filename}" -vf "pad=width=640:height=352:x=222:y=0:color=black" "${video}" >/dev/null 2>&1
    fi
  done
}

generate_ts()
{
  echo "Generating intermediary format..."
  for video in tmp/backup/*.mp4; do
    filename=$(basename "${video}")
    filename="${filename%.*}" # get rid of extension
    filename="${filename}.ts" # add .ts extension
    ffmpeg -i "${video}" -c copy -bsf:v h264_mp4toannexb -f mpegts "tmp/desktop/${filename}" >/dev/null 2>&1
  done
  backup "tmp/desktop"
}

concat_videos()
{
  echo "Concatenating videos..."
  command="concat:"
  for video in tmp/backup/*.ts; do
    command="${command}${video}|"    
  done
  command="ffmpeg -y -i \"${command%?}\" -c copy -bsf:a aac_adtstoasc output.mp4 >/dev/null 2>&1"
  eval $command
}


main()
{
  clear
  setup
  backup "videos"
  fix_dates # adjust past midnight videos
  cut_videos # cut all videos to 1 second
  pad_vertical_videos
  generate_ts # intermediary format for concatenation
  concat_videos
  clear
  echo "Done! :) \nCheck out the result video \"output.mp4\""
  exit 0;
}

main
