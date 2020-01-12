@echo OFF
prompt $g
set current_dir=%~dp0
echo Inicializando MATLAB e rodando script, aguarde...
matlab -nodisplay -nosplash -nodesktop -r "run('%current_dir%\src\controller_varios_testes.m'), exit" /wait >CON