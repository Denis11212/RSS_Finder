#!/bin/sh

# Возможно, когда-нибудь интегрирую это всё в скрипт rss_paths_finder.sh

# Проверка на наличие аргумента и соответсвенно действия.
if [ $# -eq 0 ]; then
	while true; do
	read -p "Хотите указать путь к папке для сканирования? [д/Н]: " answer
	case "$answer" in
		Д|д|Да|да|Y|y|Yes|yes)
			while true; do
				read -rp "Укажите путь к папке для сканирования файлов этой папке и во всех включенных папках: " main_folder
				# Проверка существования папки
				if [ -d "$main_folder" ]; then
					break  # Прерывание цикла, если папка найдена
				else
					echo "Папка '$main_folder' не найдена. Проверьте правильность введённого пути и попробуйте снова."
				fi
			done
			break
			;;
		""|Н|н|Нет|нет|N|n|No|no)
			main_folder=PathsFind
			mkdir -p "$main_folder"
			echo "Папка $(realpath "$main_folder") создана (или уже была ранее создана), туда нужно скопировать все файлы и папки для сканирования, а затем нажать любую кнопку для начала процесса, в котором $0 обработает каждый файл в этой папке и во всех включенных папках."
			head -n 1
			break
			;;
		*)
		echo "Неправильный ввод. Попробуйте еще раз."
		continue
		;;
		esac
	done
else
  main_folder="$1" 
fi

main_folder="without_category"

find "$main_folder" -type f -exec ./rss_paths_finder.sh -s {} \;