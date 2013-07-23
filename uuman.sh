#!/bin/bash

#Файл с хостами
IP_HOST="ip.txt"
#Файл ssh ключа
SSH_KEY="/root/.ssh/id_rsa.pub"
#Учетка администратора на хосте
ADMIN="admin"
#IP nfs сервера
SHARE_IP="192.168.0.1"
#Общая папка лог файлов
LOGDIR="/etc/uuman/log"
#Логи пользователей
USER_LOG="/etc/uuman/log/userlog"
#Логи по датам
DATE_LOG="/etc/uuman/log/datelog"
#Логи обновлений
UPDATE_LOG="/etc/uuman/log/updatelog"
#Рабочая папка скрипта
WORKD="/etc/uuman"
#e-mail администратора
EMAIL="adm@example.com"

#Функция для обновления информации о хостах
CHECK_UPDATEA()
{
	#2012_11_23
	DATEFN=`date "+%Y_%m_%d"`
	#Счетчик
	i=0
	#Обрабатываем каждую строку файла
	cat $WORKD/$IP_HOST | while read line; do
		USERN=`echo $line | sed 's/\ .*//'`
		#Получаем IP из строки
		IP=`echo $line | grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}'`
		#Проверка существования файла
		if [ ! -f $USER_LOG/$USERN.log ]; then
			touch $USER_LOG/$USERN.log
			chown nfsnobody: $USER_LOG/$USERN.log
			chmod 777 $USER_LOG/$USERN.log
		fi
		if [ ! -f $LOGDIR/.menu_log/$IP.log ]; then
			touch $LOGDIR/.menu_log/$IP.log
			chown nfsnobody: $LOGDIR/.menu_log/$IP.log
			chmod 777 $LOGDIR/.menu_log/$IP.log
		fi
		#Доступность хоста
		if ping -c 1 -s 1 -W 1 $IP > /dev/null 2>&1; then
			i=`expr $i + 1`
			#Проверка что выбрано из меню
			if [ "$SELECT" = "2" ]; then
				#Для каждого хоста отдельный screen
				expect $WORKD/update $IP $USERN $ADMIN $SHARE_IP &
			elif [ "$ARG" = "check" ]; then
				#Для каждого хоста отдельный screen
				expect $WORKD/update $IP $USERN $ADMIN $SHARE_IP &
			else
				#Выполнять обновление пакетов
				expect $WORKD/package $IP $USERN $ADMIN $SHARE_IP > $UPDATE_LOG/$USERN.log &
			fi
		else
			#Если хост не доступен пишем в логи соответсующий вывод
			#Данные в лог ошибок
			echo $(date "+%Y.%m.%d/%H:%M:%S") >> $LOGDIR/err.txt
			echo $USERN \- not connected >> $LOGDIR/err.txt
			echo "" >> $LOGDIR/err.txt
			#Данные в общий лог
			echo $(date "+%Y.%m.%d/%H:%M:%S") \| $USERN \- not connected >> $LOGDIR/upd.txt
			echo "" >> $LOGDIR/upd.txt
			#Данные в лог текущей даты
			echo $(date "+%Y.%m.%d/%H:%M:%S") \| $USERN \- not connected >> $DATE_LOG/UPD-$DATEFN.txt
			echo "" >> $DATE_LOG/UPD-$DATEFN.txt
			#Если хост когда-либо был в сети, не ставить статус not connected в меню
			NT=`cat $LOGDIR/.menu_log/$IP.log | grep "AvailableUpdates"`
			if [ -z "$NT" ]; then
				echo -n "$USERN | $IP | Unknown | Unknown | $(date "+%Y.%m.%d/%H:%M:%S")" > $LOGDIR/.menu_log/$IP.log
			fi
		fi
	done
	#Информация по хостам в общий лог
	ls $USER_LOG | grep .log | while read TXT; do
		paste $USER_LOG/$TXT >> $LOGDIR/upd.txt
		echo >> $LOGDIR/upd.txt
		#В лог на текущую дату
		paste $USER_LOG/$TXT >> $DATE_LOG/UPD-$DATEFN.txt
		echo >> $DATE_LOG/UPD-$DATEFN.txt
	done
}

#Функция проверки и обновления отдельного хоста
CHECK_IP()
{
	#Информация о конкретном IP
	echo -n "Enter Name/Ip:"
	read NIP
	#Получаем IP
	IP=`cat $WORKD/$IP_HOST | grep "$NIP" | grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}'`
	#Находим пользовтеля и получаем его имя
	USERN=`cat $WORKD/$IP_HOST | grep "$NIP" | sed 's/\ .*//'`
	#Доступен ли хост
	if ping -c 1 -s 1 -W 1 $IP > /dev/null 2>&1; then
		if [ "$SELECT" = "1" ]; then
			$WORKD/update $IP $USERN $ADMIN $SHARE_IP
			cat $USER_LOG/$USERN.log
		else
			$WORKD/package $IP $USERN $ADMIN $SHARE_IP
			cat $USER_LOG/$USERN.log
		fi
	else
		#Уведомляем и записываем в лог ошибок
		echo "Computer is offline"
		echo -n "$USERN | $IP | Unknown | Unknown | $(date "+%Y.%m.%d/%H:%M:%S")" > $LOGDIR/.menu_log/$IP.log
		echo $(date "+%Y.%m.%d/%H:%M:%S") >> $LOGDIR/err.txt
		echo $USERN $IP \- not connected >> $LOGDIR/err.txt
		echo "" >> $LOGDIR/err.txt
	fi
}

#Функция для быстрого старта
STARTUP()
{
	#Счетчик
	i=0
	#Обрабатываем каждую строку файла
	cat $WORKD/new_hosts.txt | while read line; do
		USERN=`echo $line | sed 's/\ .*//'`
		#Получаем IP из строки
		IP=`echo $line | grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}'`
		#Доступность хоста
		if ping -c 1 -s 1 -W 1 $IP > /dev/null 2>&1; then
			i=`expr $i + 1`
			expect $WORKD/startup "$IP" "$USER" "$PASS" &
		else
			#Если хост не доступен пишем в логи соответсующий вывод
			#Данные в лог ошибок
			echo $(date "+%Y.%m.%d/%H:%M:%S") >> $LOGDIR/err.txt
			echo $USERN \- not connected >> $LOGDIR/err.txt
			echo "" >> $LOGDIR/err.txt
		fi
	done
	#Очистка файла с новыми хостами
	cat /dev/null > $WORKD/new_hosts.txt
}

#Функция генерация общего мини-отчета по хостам
MAIN()
{
	if [ ! -d $DATE_LOG ]; then
		mkdir -p -m 777 $DATE_LOG
	fi
	if [ ! -d $LOGDIR/.menu_log ]; then
		mkdir -p -m 777 $LOGDIR/.menu_log
	fi
	if [ ! -d $USER_LOG ]; then
		mkdir -p -m 777 $USER_LOG
	fi
	if [ ! -d $UPDATE_LOG ]; then
		mkdir -p -m 777 $UPDATE_LOG
	fi
	if [ -f $LOGDIR/MENU.txt ]; then
		rm -f $LOGDIR/MENU.txt
	fi
	ls $LOGDIR/.menu_log | grep .log | while read MENU; do
	#Все для красивого вывода в файл(возврат строки и замена символов)	
	TEXT=`paste -s -d '|' $LOGDIR/.menu_log/$MENU | sed 's/|/ | /g;s/-/|/g'`
	echo $TEXT >> $LOGDIR/MENU.txt
	done
	if [ -f $LOGDIR/MENU.txt ]; then
		#Очистка экрана и табличный вывод файла
		clear && cat $LOGDIR/MENU.txt | column -t
	else
		clear
	fi
}

#Общая информация по хостам
INFOHOST()
{
	if [ -f $LOGDIR/MENU.txt ]; then
		#Офлайн
		OFFLINE=0
		while read line; do
			#Фильтруем и получаем дату
			DATE=`echo $line | sed 's/.*\ //' | sed 's/\/.*//' | sed 's/\.//g'`
			UKNOWN=`cat $LOGDIR/MENU.txt | grep "Unknown" | wc -l`
			if [ "$DATE" != $(date "+%Y%m%d") ]; then
				OFFLINE=`expr $OFFLINE + 1`
			fi
		done < <(cat $LOGDIR/MENU.txt)
		let "OFFLINE=$OFFLINE+$UKNOWN"
		#Всего хостов
		ALLHOSTS=`cat $LOGDIR/MENU.txt | wc -l`
		#Полностью обновлены
		ALLUPDATE=`cat $LOGDIR/MENU.txt | grep "AvailableUpdates:0" | wc -l`
		#Доступны для обновления
		let "AVUPDATE=$ALLHOSTS - $ALLUPDATE"
		#Вывод
		echo -e "\E[31mAll hosts:$ALLHOSTS Fully updated:$ALLUPDATE Updatable:$AVUPDATE Offline:$OFFLINE"; tput sgr0
	fi
}

#Добавление хоста
ADD()
{
	#Вводим имя - ip
	echo "Input Name - Ip:"
	read NIP
	if [ -z $NIP ]; then
		echo "Empty"
		MENU
	else
		echo "$NIP" >> $WORKD/$IP_HOST
		#Получаем IP
		IP=`echo "$NIP" | grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}'`
		#Находим пользовтеля и получаем его имя
		USERN=`echo "$NIP" | sed 's/\ .*//'`
		#Проверка существования файла
		if [ ! -f $USER_LOG/$USERN.log ]; then
			touch $USER_LOG/$USERN.log
			chown nfsnobody: $USER_LOG/$USERN.log
			chmod 777 $USER_LOG/$USERN.log
		fi
		if [ ! -f $LOGDIR/.menu_log/$IP.log ]; then
			touch $LOGDIR/.menu_log/$IP.log
			chown nfsnobody: $LOGDIR/.menu_log/$IP.log
			chmod 777 $LOGDIR/.menu_log/$IP.log
		fi
		#Доступен ли хост
		if ping -c 1 -s 1 -W 1 $IP > /dev/null 2>&1; then
			#Проверка известного хоста в файле
			KNOWNHOST=`cat ~/.ssh/known_hosts | grep "$IP"`
			if [ -z "$KNOWNHOST" ]; then
				ssh-copy-id -i $SSH_KEY $ADMIN@$IP
				sleep 30s
			fi
			$WORKD/update $IP $USERN
			cat $USER_LOG/$USERN.log
		else
			#Уведомляем и записываем в лог ошибок
			echo "Computer is offline"
			echo -n "$USERN | $IP | Unknown | Unknown | $(date "+%Y.%m.%d/%H:%M:%S")" > $LOGDIR/.menu_log/$IP.log
			echo $(date "+%Y.%m.%d/%H:%M:%S") >> $LOGDIR/err.txt
			echo $USERN $IP \- not connected >> $LOGDIR/err.txt
			echo "" >> $LOGDIR/err.txt
		fi
	fi
}

#Удаление хостов
DEL()
{
	#Вводим имя, ip
	echo "Input Name/Ip:"
	read NIP
	if [ -z $NIP ]; then
		echo "Empty"
		MENU
	else
		#Получаем IP
		IP=`cat $WORKD/$IP_HOST | grep "$NIP" | grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}'`
		#Находим пользовтеля и получаем его имя
		USERN=`cat $WORKD/$IP_HOST | grep "$NIP" | sed 's/\ .*//'`
		#Получаем строку из файла
		STROKA=`cat $WORKD/$IP_HOST | grep "$NIP"`
		#Удаляем строку из файла хостов
		sed -i "/$STROKA/d" $WORKD/$IP_HOST
		#Удаляем лог файлы
		rm -f $USER_LOG/$USERN.log $LOGDIR/.menu_log/$IP.log  $UPDATE_LOG/$USERN.log
	fi
}

#Уведомление о давно не обновленных хостах
MAIL()
{
	DATENOW=`date "+%Y%m%d"`
	#Дата 14 дней назад
	DATE5DAY=`date "+%Y%m%d" -d "14 day ago"`
	if [ -f "$LOGDIR/mail.txt" ]; then
		rm -f $LOGDIR/mail.txt
	fi
	ls $LOGDIR/.menu_log | grep .log | while read MENU; do
		#Все для красивого вывода в файл(возврат строки и замена символов)	
		TEXT=`paste -s -d '|' $LOGDIR/.menu_log/$MENU | sed 's/|/ | /g;s/-/|/g'`
		echo $TEXT >> $LOGDIR/MENU.txt
	done
	#Каждая строка файла
	cat $LOGDIR/MENU.txt | while read line; do
		#Получаем дату из строки
		DATE=`echo $line | sed -e 's/.*|//' | sed -e 's/\/.*$//' | sed -e 's/\.//g'`
		#Если дата больше 14 дней, добавить информацию в письмо.
		if [ "$DATE" -lt "$DATE5DAY" ]; then
			echo $line >> $LOGDIR/mail.txt
		fi
	done
	#Отправка письма
	if [ -f "$LOGDIR/mail.txt" ]; then
		cat $LOGDIR/mail.txt | mail $EMAIL
	fi
}

#Меню скрипта
MENU() 
{
	echo
	echo "1.Get update-information for ubuntu-host (by custom IP-address)"
	echo "2.Get update-information for all ubuntu-hosts (uses file with IP-addresses)"
	echo "3.Update packages for ubuntu-host (by custom IP-address)"
	echo "4.Update packages for all hosts (uses file with IP-addresses)"
	echo "5.View error-connection log"
	echo "6.View update log for ubuntu-host"
	echo "7.Get package-information for Ubuntu-host"
	echo "8.Add host"
	echo "9.Delete host"
	echo "10.Refresh"
	echo "11.Exit"
	read SELECT
	
	case $SELECT in
	1)
		CHECK_IP
		MENU
		;;
	2)
		#Обновить информацию о всех хостах
		CHECK_UPDATEA > /dev/null 2>&1
		sleep 5s
		MAIN
		INFOHOST
		MENU
		;;
	3)
		CHECK_IP
		MENU
		;;
	4)
		#Обновить все хосты
		CHECK_UPDATEA > /dev/null 2>&1
		sleep 5s
		MAIN
		INFOHOST
		MENU
		;;
	5)
		#Показать лог ошибок
		cat $LOGDIR/err.txt
		MENU
		;;
	6)
		#Лог обновления с хоста
		echo "Enter Name/Ip:"
		read IP
		USERN=`cat $WORKD/$IP_HOST | grep "$IP" | sed 's/ .*//'`
		cat $UPDATE_LOG/$USERN.log
		MENU
		;;
	7)
		#Информация о пакетах с хоста
		echo "Enter Name/Ip:"
		read IP
		USERN=`cat $WORKD/$IP_HOST | grep "$IP" | sed 's/ .*//'`
		cat $USER_LOG/$USERN.log
		MENU
		;;
	8)	
		#Добавление хоста
		ADD
		MAIN
		INFOHOST
		MENU
		;;
	9)
		#Удаление хоста
		DEL
		MAIN
		INFOHOST
		MENU
		;;
	10)
		#Обновить
		MAIN
		INFOHOST
		MENU
		;;
	11)
		exit 0
		;;
	*)
		MENU
	esac
}

#Запуск скрипта с параметрами
#Получаем параметр
ARG=$1
USER=$2
PASS=$3
	case $ARG in
	check)
		CHECK_UPDATEA > /dev/null 2>&1
		;;
	update)
		CHECK_UPDATEA > /dev/null 2>&1 
		;;
	comandcron)
		COMANDCRON > /dev/null 2>&1
		;;
	mail)
		MAIL > /dev/null 2>&1
		;;
	startup)
		STARTUP
		;;
	*)
		MAIN
		INFOHOST
		MENU
	esac
exit 0