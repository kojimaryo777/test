
HOST="localhost"
KEY="a6c4e2afa869049fc560dc595ee255f3d0fbf2ee"

#対象のアカウントIssue_idが所属するプロジェクトIDの取得を行う
target_json=`curl -s http://${HOST}/issues/${1}.json?key=${KEY}`

project_id=`echo $target_json | jq -r '.issue.project.id'`

#echo "project_id:$project_id"

#redmine api のステータスのリストを取得し、第２引数で渡されたステータスを比較して、対象とするステータスIDを取得する
status_json=`curl -s http://${HOST}/issue_statuses.json?key=${KEY}`
status_id=(`echo ${status_json} | jq -r '.issue_statuses[] | select(.name == "'${2}'") | .id'`)

#is_closed_flg=(`echo ${status_json} | jq -r '.issue_statuses[] | select(.name == "'${2}'") | .is_closed'`)

while true; do
  target_json=`curl -s "http://${HOST}/issues.json?project_id=${project_id}&status_id=*"`

#echo "$target_json" | jq . 

  target_id_array=(`echo ${target_json} | jq '.issues[] | select(.status.id != '${status_id}') | .id'`)
  parent_id_array=(`echo ${target_json} | jq '.issues[] | select(.parent.id !=null and .status.id != '${status_id}') | .parent.id'`)

  c_flg=""
  echo 削除対象チケット：${target_id_array[@]}
  echo 依存関係チケットリスト：${parent_id_array[@]}

  if [ ${#parent_id_array[@]} -eq 0 ]; then
      echo "依存関係がないことを確認した為、残りのチケットのステータスの変更を行います"
      c_flg=true
    fi
    if [ ${#target_id_array[@]} -eq 0 ]; then
      echo "すべての対象のチケットのステータスの変更を完了しました"
      exit 0
    else
    for t_id in ${target_id_array[@]};do #変更対象のチケットIDの数だけループする
      for p_id in ${parent_id_array[@]};do #parent_idとして登場する配列のリスト分だけループする
        if [[ ${t_id} == ${p_id} ]]; then #parent_id の配列内に一致する数字を見つけたらそれはまだ変更できないチケットであるのでSKIP
          c_flg=false
          break
        fi
        c_flg=true
      done
      if [[ ${c_flg} == true ]]; then
        echo "${t_id}のステータス変更を試みます"
        #parent_listに存在が確認できなかったチケットはクローズ処理を行う
        update_json_template=$(cat << EOS
{
  "issue": {
    "status_id": ${status_id}
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
