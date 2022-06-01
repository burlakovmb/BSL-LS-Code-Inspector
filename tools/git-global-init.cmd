@echo off
@chcp 65001

@rem for current user

:GitUserName
cls
echo.
echo.
echo Enter your UserName for this Git Repository
echo   (for example - Snitkovski)
echo.
set /p GitUserName="Your choice: "

if not defined GitUserName (echo Make right choice, please!
                            echo your GitUserName = %GitUserName% 0
                            pause
                            goto GitUserName)
if "%GitUserName%"=="" (echo Make right choice, please!
                        echo your GitUserName = %GitUserName% 1
                        pause
                        goto GitUserName)
if "%GitUserName%"==" " (echo Make right choice, please!
                         echo your GitUserName = %GitUserName% 2
                         pause
                         goto GitUserName)

:GitEMail
cls
echo.
echo.
echo Enter your GitEMail for this Git Repository
echo   (for example - sam@1c.ro)
echo.
set /p GitEMail="Your choice: "

if not defined GitEMail (echo Make right choice, please!
                         pause
                         goto GitEMail)
if "%GitEMail%"=="" (echo Make right choice, please!
                     pause
					 goto GitEMail)
if "%GitEMail%"==" " (echo Make right choice, please!
                      pause
					  goto GitEMail)


:m1
cls
echo.
echo.
echo your GitUserName = %GitUserName%
echo your GitEMail = %GitEMail%
echo.
echo Is it correct?
echo.
echo 1 - YES
echo 2 - no
echo 3 - END
echo.
set /p choice="Your choice: "

if not defined choice goto m1
if "%choice%"=="1" (goto next)
if "%choice%"=="2" (goto GitUserName)
if "%choice%"=="3" (exit)
if "%choice%"=="4" (exit)
if "%choice%"=="5" (exit)
if "%choice%"=="6" (exit)
if "%choice%"=="7" (exit)
if "%choice%"=="8" (exit)
if "%choice%"=="9" (exit)
echo.
echo Make right choice, please!
echo.
echo.
pause
goto m1


:next
echo on
git config user.name "%GitUserName%"
git config user.email %GitEMail%

git config core.quotePath false

@rem -=-=-=-=-=-=-=-=-=-=-=-=-=-
@rem https://git-scm.com/book/en/v2/Git-Basics-Git-Aliases
git config --global alias.co checkout
git config --global alias.br branch
git config --global alias.cm commit
git config --global alias.st status

@rem -=-=-=-=-=-=-=-=-=-=-=-=-=-
@rem git config --global alias.unstage 'reset HEAD --'
@rem git config --global alias.last 'log -1 HEAD'


@rem -=-=-=-=-=-=-=-=-=-=-=-=-=-
@rem Настройка core.autocrlf с параметрами "true" и "input" делает все переводы строк текстовых файлов в главном (remote) репозитории одинаковыми
@rem core.autocrlf true - git автоматически конвертирует CRLF --> LF в момент коммита и автоматически конвертирует обратно LF --> CRLF (при использовании Windows) в момент выгрузки кода из репозитория на файловую систему
@rem core.autocrlf input - конвертация CRLF --> LF только при коммитах (при использовании Mac/Linux)

@rem Если core.safecrlf установлен на "true" или "warn", Git проверяет, является ли преобразование  обратимым для текущей настройки core.autocrlf (см.выше)
@rem core.safecrlf true - отвержение необратимого преобразования LF <--> CRLF - полезно, когда есть специфические бинарники, похожие на текстовые файлы
@rem core.safecrlf warn - только выводит предупреждение, но принимает необратимый переход


@rem -=-=-=-=-=-=-=-=-=-=-=-=-=-
@rem for Windows
git config core.autocrlf true
@rem git config --loсal core.autocrlf false
@rem git config --loсal core.safecrlf true
git config core.safecrlf warn
@rem git config --loсal core.safecrlf false


@rem -=-=-=-=-=-=-=-=-=-=-=-=-=-
@rem for Linux and MacOS
@rem git config --loсal core.autocrlf input
@rem git config --loсal core.safecrlf true

git config http.postBuffer 1048576000

@echo.
@echo do next two lines in Administration mode only (run CMD with Administrator's rights)
@rem git config --system core.longpaths true
@rem SET LC_ALL=C.UTF-8


@rem -=-=-=-=-=-=-=-=-=-=-=-=-=-
@rem   from GitSync
git config --local core.quotepath false
git config --local gui.encoding utf-8
git config --local i18n.commitEncoding utf-8
git config --local diff.renameLimit 1
git config --local diff.renames false


:END
