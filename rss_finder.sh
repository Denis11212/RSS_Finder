#!/bin/sh

# Перечисление переменных для дальнейшего использования
rss_paths_list='rss_paths_list.txt' # Файл со списком путей для подбора, путь по умолчанию

# Различные проверки перед исполнением скрипта

# Проверяем наличие аргументов (URL страницы)
if [ $# -eq 0 ]; then
  read -rp "Введите URL: " url
else
  url="$1"
fi

# Проверяем URL на корректность
while true; do
  case "$url" in
    http://*|https://*)
      break ;;
    *)
      echo "Некорректный формат URL. Пожалуйста, введите корректный URL (например, https://example.com или http://example.ru и так далее)."
      read -p "Введите URL: " url
  esac
done

# Удаление пробелов
url=`echo "$url" | tr -d ' '`

# Проверка наличия слеша в конце URL
case "$url" in
  */) ;;  # Если URL уже заканчивается на "/", ничего не делаем
  *) url="$url/" ;;  # В противном случае добавляем слеш
esac

# Создание записи в файле о начале поиска RSS
echo "Все успешно найденные каналы будут храниться в файле rss_links.txt, начиная с последней строки 'Найденные ссылки на каналы'. Если после этой строчки не будет никаких каналов, значит банально не удалось найти ни одного rss канала."
echo "" >> rss_links.txt
echo "Найденные ссылки на каналы от $(date +"%Y-%m-%d")" >> rss_links.txt

# Перечисление функций RSS

# Проверка страницы на наличие rss тегов, для проверки достаточно подсунуть link_tag_check ссылка_на_проверку

silent_link_tag_check() {
    # Получаем контент по указанному URL
    curl_output=`curl --silent --header "Accept: application/rss+xml, application/atom+xml" "$1"`

    # Проверяем наличие тега <rss> или <feed>
    echo "$curl_output" | grep -Eq '<rss|<feed'
    if [ $? -eq 0 ]; then
        echo "RSS канал найден по адресу: $1"
        echo "$(date +"%T.%N") RSS канал найден по адресу: $1" >> rss_links.txt
	fi
}

ask_link_tag_check() {
    # Получаем контент по указанному URL
    curl_output=`curl --silent --header "Accept: application/rss+xml, application/atom+xml" "$1"`

    # Проверяем наличие тега <rss> или <feed>
    echo "$curl_output" | grep -Eq '<rss|<feed'
    if [ $? -eq 0 ]; then
        echo "RSS канал найден по адресу: $1"
        echo "$(date +"%T.%N") RSS канал найден по адресу: $1" >> rss_links.txt
		while true; do
			echo -n  "Продолжить поиск? [Д/н]: "
			read answer
			case "$answer" in
				""|Д|д|Да|да|Y|y|Yes|yes)
					break
					;;
				Н|н|Нет|нет|N|n|No|no)
					final_report
					exit 0
					;;
				*)
				echo "Неправильный ввод. Попробуйте еще раз."
				continue
				;;
			esac
		done
		return 0
		else
		return 1
    fi
}

# Предложение посмотреть результаты парсинга запросов.
final_report() {
echo "Поиск завершен, с результатами можно ознакомиться в файле rss_links.txt"
		while true; do
			echo -n "Показать итоговые результаты успешно собранных ссылок? [Д/н]: "
			read answer
			case "$answer" in
				""|Д|д|Да|да|Y|y|Yes|yes)
					tac rss_links.txt | sed -e '/Найденные ссылки на каналы/q' | tac
					exit 0;;
				Н|н|Нет|нет|N|n|No|no)
					exit 0
					;;
				*)
				echo "Неправильный ввод. Попробуйте еще раз."
				continue
				;;
			esac
		done
}

# Функция для поиска RSS-ссылок в HTML-коде
find_rss_in_html() {
  
  # Ищем ссылки на RSS-каналы с помощью xmllint и grep
  rss_links=$(echo "$html_content" | xmllint --html --xpath '//head/link[@type="application/rss+xml" or @type="application/atom+xml"]/@href' - 2>/dev/null | grep -Eo '(http|https)://[^"]+')

  # Если ничего не нашли, сообщаем об этом
  if [ -z "$rss_links" ]; then
    echo "Не удалось найти ссылки на RSS-каналы в HTML-коде страницы."
  fi

  # Проходимся по всем найденным ссылкам
  for rss_link in $rss_links; do
    silent_link_tag_check $rss_link
  done
}

# Функция для выполнения подбора путей посредством базы данных
try_paths() {

	# Проверка существования файла со списоком путей для поиска rss
	if ! [ -f $rss_paths_list ]; then
	echo "Файл со списком путей для подбора rss адреса не найден. Для корректной работы поместите этот файл "$rss_paths_list" в папке "$PWD" рядом с этим скриптом "$0". Сформировать файл "$rss_paths_list" можно с помощью скрипта rss_paths_finder.sh"
		exit 1
	fi

    # Получаем количество строк без комментариев (начинающихся с '#')
    total_paths=$(grep -cE '^[^[:space:]#]' $rss_paths_list)
    
    # Инициализируем счетчик для вывода прогресса
    counter=0

    for path in `awk '!/^#/ && NF' $rss_paths_list`; do
        # Инкрементируем счетчик
        counter=`expr $counter + 1`
        
        # Выводим текущий прогресс
        echo "Проверка суффикса $counter/$total_paths: $url$path"
        
        ask_link_tag_check "$url$path"
    done
echo "Все суффиксы в база денных $rss_paths_list закончились. При желании вы можете самостоятельно поменять эту базу данных, либо воспользоваться другими методами подбора."
}

# Функция для выполнения подбора суффиксов методом ручного ввода суффиксов с клавиатуры
try_paths_user () {
    while true; do
        read -rp "Введите суффикс (например, feed/): " path
        echo "Проверка суффикса: $url$path"
        if ! ask_link_tag_check "$url$path"; then
        echo "По адресу $url$path RSS поток не найден."
		fi
        read -rp "Продолжить поиск с другим суффиксом? [Д/н]: " answer
		case "$answer" in
            Н|н|Нет|нет|N|n|No|no)
                break
                ;;
            ""|Д|д|Да|да|Y|y|Yes|yes)
                continue
                ;;
            *)
                echo "Неправильный ввод. Попробуйте еще раз."
                continue
                ;;
        esac
        
		done
}

# Функция для выполнения автоматического подбора суффиксов, содержащих все сочетания char='abcdefghijklmnopqrstuvwxyz0123456789._-~!$&\'()*+,;=:@' ну и, возможно, если сайт из кириллицы, например *.рф, то ещё и алфавит нужно будет добавить абвгдеёжзийклмнопрстуфхцчшщъыьэюя пока ещё не сделана. Как из-за того, что я не совсем понимаю как правильно это реализовать, так и потому что эффективность данного метода весьма сомнитальная. Но пусть как идея будет.
# Так же для поиска каналов использовать поддомены сайта  такие как /robots.txt или /sitemap.xml
#try_paths_broot () {
#echo "Не сделал такого алгоритма, может, когда-то потом запилю"
#}

# Выполнение основного алгоритма программы с помощью функций.

# Получение HTML-контента страницы
html_content=$(curl --silent "$url")

# Поиск rss каналов на странице по html коду (выполняется всегда, потому нет диалога).
find_rss_in_html

# Поиск rss каналов по доменному имени методом подбора суффиксов
while true; do
	read -rp "Попробовать найти rss адреса методом подбора суффиксов из базы данных $rss_paths_list? [Д/н]: " answer
	case "$answer" in
		""|Д|д|Да|да|Y|y|Yes|yes)
			try_paths
			break
			;;
		Н|н|Нет|нет|N|n|No|no)
			break
			;;
		*)
			echo "Неправильный ввод. Попробуйте еще раз."
			continue
			;;
		esac
done

# Поиск rss каналов по доменному имени методом ручного ввода суффиксов с клавиатуры
while true; do
	read -rp "Попробовать найти rss адреса методом ручного ввода суффиксов с клавиатуры и их проверки? [Д/н]: " answer
	case "$answer" in
		""|Д|д|Да|да|Y|y|Yes|yes)
			try_paths_user
			break
			;;
		Н|н|Нет|нет|N|n|No|no)
			break
			;;
		*)
			echo "Неправильный ввод. Попробуйте еще раз."
			continue
			;;
		esac
done

# Поиск rss каналов по доменному имени методом брута (находится в разработке, потому закомментирован)
#while true; do
#	read -rp "Попробовать найти rss адреса методом простого перебора (успех будет крайне маловероятен и сайт может вас забанить за очень частые запросы) всех физически возможных адресов банально по алфавиту (слабая версия подбирателя пароля)? [Д/н]: " answer
#	case "$answer" in
#		""|Д|д|Да|да|Y|y|Yes|yes)
#			try_paths_broot
#			break
#			;;
#		Н|н|Нет|нет|N|n|No|no)
#			break
#			;;
#		*)
#				echo "Неправильный ввод. Попробуйте еще раз."
#				continue
#				;;
#			esac
#done

final_report
exit 0