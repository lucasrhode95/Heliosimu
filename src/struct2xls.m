% Salva uma estrutura struct num arquivo excel.
%>PARÂMETROS
% -dir: string do diretório (relativo ou absoluto) do arquivo
%       relatórios/export.xlsx, por exemplo
%
% -nomePlanilha: planilha1, planilha2, etc... no mesmo arquivo
%
% -struct_in: struct ou array de struct que se deseja salvar no excel
%
% -nao_salvar: lista das colunas que não se deseja salvar, por exemplo
%              {'Alim' 'SimuDFIG' 'SimuFSIG'}
%
% -modo: 'novo' para criar arquivo excel do zero
%         ou 'concatenar' para tentar concatenar (as colunas existentes
%         precisam ser iguais as novas em nome e quantidade)
function struct2xls(dir, nomePlanilha, struct_in, nao_salvar, modo)
    %remove as colunas indesejadas
	if ~isempty(nao_salvar)
		struct_in = rmfield(struct_in, nao_salvar);
	end

    %coleta nome das colunas e valores de cada linha da futura tabela
	[header, valores] = struct2mat(struct_in);	
	
    %coleta dimensões da struct
    [qtdColunas, celulasPorCampo, qtdLinhas] = size(valores);
	
    %testes chatos
    checkDimension(celulasPorCampo); %caso dimensão esteja errada gera erro
    
    %esta seção do código pode ser removida caso não haja necessidade de
    %concatenar a tabela. Basta substituir por linhasExistentes = {}.
    % Testa se já existe arquivo. Se já existir, coloca dados anteriores
    %no topo da tabela (para não perder dados que já estiverem no arquivo)
    [status, linhasExistentes]= checaArqExistente(dir, header, modo); 
    if status == 2 && ~strcmp(modo, 'novo')
        disp('AVISO: COLUNAS NOVAS E DO ARQUIVO ANTIGO NÃO COINCIDEM. TALVEZ TENTE UM EXCEL NOVO?');
        return
    elseif status == -1
        disp('AVISO: NÃO FOI POSSÍVEL DETERMINAR O STATUS DO ARQUIVO ANTIGO');
        return
    end
    %linhasExistentes = {};
    
    %converte struct internos para string
    valores = innerStruct2str(valores, qtdLinhas, qtdColunas);
    
    %--CRIA LINHAS E COLUNAS NO FORMATO QUE XLSWRITE() ACEITA    ---- DEPRECADO 
    %info: valores(coluna,
    %              subindice do parametro (sempre = 1 pois só aceita 1 dado por célula),
    %              linha (1 por simulação)
%     tabela = cell(qtdLinhas, qtdColunas);
%     for i = 1:qtdLinhas
%         tabela(i, :) = valores(:, 1, i)';
%     end
    
	tabela = [header valores];

    %escreve tudo no arquivo, incluindo o header
    try
        warning('off', 'MATLAB:xlswrite:AddSheet'); %ignorar warning
        
%         xlswrite(dir, [header'; linhasExistentes; tabela], nomePlanilha); %<<< AQUI É ONDE CRIA O ARQUIVO (modo linha-linha)
        xlswrite(dir, tabela, nomePlanilha); %<<< AQUI É ONDE CRIA O ARQUIVO (modo coluna-coluna não suporta (ainda) append)
        
        warning('on', 'MATLAB:xlswrite:AddSheet'); %reativa warning
	catch e
		disp(e.identifier);
        disp('Não foi possível exportar para Excel. Planilha está aberta, talvez?');
    end
end





%desaninha os structs e coleta seus valores
% @TODO: tratar vetores aninhados
function [header, valores] = struct2mat(structIn)
	%
	headerTudo = [];
	valoresTudo = [];
	
	header  = fieldnames(structIn);
	valores = struct2cell(structIn);
	
	for i = 1:length(header)
		if isstruct(structIn.(header{i}))
			[headerInner, valoresInner] = struct2mat(structIn.(header{i}));
			for j = 1:length(headerInner)
				headerTudo = [headerTudo, header{i} + "." + headerInner{j}];
				valoresTudo = [valoresTudo, "" + valoresInner{j}];
			end
		else
			headerTudo = [headerTudo, ""+header{i}]; % ""+ é para converter para string, se usar só char concatena tudo
			valoresTudo = [valoresTudo, ""+valores{i}];
		end
	end
	
	header = headerTudo';
 	valores = valoresTudo';
end


%coleta quantidade de campos e linhas. Testa quantidade de informações
%por célula do excel: no máximo 1 dado / célula
function checkDimension(celulasPorCampo)
    if celulasPorCampo > 1
        msg = 'Error in struct2xls function:';
        msg = [msg 'só consigo escrever uma info por célula do excel'];
        msg = [msg ', confira o struct de entrada'];
        error(msg);
    end
end

function valores = innerStruct2str(valores, qtdLinhas, qtdColunas)
    toString = @(var) evalc('disp(var)');
    for i = 1:qtdLinhas
        for j = 1:qtdColunas
            temp = valores(j, 1, i);
            if isa(temp{1}, 'struct')
                valores(j, 1, i) = {toString(temp{1})};
            end
        end
    end
end

%testa se o arquivo com mesmo nome já existe. Caso exista, compara os
%headers e retorna status.
%>PARAMETROS:
% -dir: string do diretório (relativo ou absoluto) do arquivo
%       relatórios/export.xlsx, por exemplo
%
% -header: saída de fieldnames() aplicada ao array struct de entrada
% -modo: 'novo' ou 'concatenar' VER DESCRIÇÃO DA FUNÇÃO struct2xls.m
%
%
%>SAÍDA:
% -status: 0 = arquivo não existe
%          1 = arquivo existe e headers são iguais
%          2 = arquivo existe e headers são diferentes
%         -1 = status não definido
% -linhasExistentes: linhas que já estão escritas no programa
function [status, linhasExistentes] = checaArqExistente(dir, header, modo)    
    %tenta encontrar arquivo no disco
    try
        [~, ~, raw] = xlsread(dir); %tenta abrir
    catch Exception
        %se não encontrar:
        if Exception.identifier == 'MATLAB:xlsread:FileNotFound' %silencia
            status = 0;
            linhasExistentes = {};
            return;
        %se ocorrer algum outro erro qualquer:
        else
            rethrow(ME2)
        end
    end
    
    %se tiver encontrado arquivo, testa o header (primeira linha)
    try
        %se header for igual:
        if isempty(setdiff(raw(1, :), header'))
            status = 1;
            linhasExistentes = raw(2:end,:);
        %header diferente:
        else
            status = 2;
            linhasExistentes = raw;
        end
    catch
        %caso ocorra algum erro na hora de comparar as os headers:
        status = 2;
        linhasExistentes = raw;
    end
    
    
    %se usuário quiser arquivo novo
    if strcmp(modo, 'novo')
        linhasExistentes = {};
        delete(dir);
    elseif strcmp(modo, 'concatenar')
    else
        error('parâmetro "modo" com valor incorreto: ou "novo" ou "concatenar"');
    end
    
    return
end