
HOST="localhost"
KEY="a6c4e2afa869049fc560dc595ee255f3d0fbf2ee"
target_json=`curl -s http://${HOST}/issues.json?issue_id=${1}&key=${KEY}`
project_id=`echo $target_json | jq -r '.issues[].project.id'`
while true; do
  target_json=`curl -s "http://${HOST}/issues.json?project_id=${project_id}&status_id=1"`
  target_id_array=(`echo ${target_json} | jq '.issues[].id'`)
  parent_id_array=(`echo ${target_json} | jq '.issues[] | select(.parent.id !=null) | .parent.id'`)
  c_flg=""
  echo 削除対象チケット：${target_id_array[@]}
  echo 依存関係チケットリスト：${parent_id_array[@]}
    if [ ${#parent_id_array[@]} -eq 0 ]; then
      echo "依存関係がないことを確認した為、残りのチケットのクローズを行います"
      c_flg=true
    fi
    if [ ${#target_id_array[@]} -eq 0 ]; then
      echo "すべての削除チケットのクローズ処理が完了しました"
      exit 0
    else
    for t_id in ${target_id_array[@]};do #削除対象のチケットIDの数だけループする
      for p_id in ${parent_id_array[@]};do #parent_idとして登場する配列のリスト分だけループする
        if [[ ${t_id} == ${p_id} ]]; then #parent_id の配列内に一致する数字を見つけたらそれはまだクローズできないチケットであるのでSKIP
          c_flg=false
          break
        fi
        c_flg=true
      done
      if [[ ${c_flg} == true ]]; then
        echo "${t_id}の削除を試みます"
        #parent_listに存在が確認できなかったチケットはクローズ処理を行う
        update_json_template=$(cat << EOS
{
  "issue": {
    "status_id": 5
  }
}
EOS
)
        curl "http://${HOST}/issues/${t_id}.json?key=${KEY}" -H "Accept: application/json" -H "Content-type: application/json" -X PUT -d "${update_json_template}" -k
        echo "${update_json_template}"
        echo "http://${HOST}/issues/${t_id}.json?key=${KEY}"
      fi
    done
  fi
done
exit