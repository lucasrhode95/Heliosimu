clear; clc;
addpath('../');

%% L� par�metros definidos no arquivo de par�metros
disp('[INFO] Carregando par�metros...');

%fonte de dados
parametros.arquivo_parametros = 'PARAMETROS.xlsx';
[num, txt, raw]= xlsread(parametros.arquivo_parametros, 'Sheet1');

[num_parametros, ~] = size(raw);
for i = 1:num_parametros
	valor_parametro = raw{i, 2};
	if isnumeric(valor_parametro)
		eval(['parametros.' raw{i, 1} ' = ' num2str(raw{i, 2}) ';']);
	else		
		eval(['parametros.' raw{i, 1} ' = ''' raw{i, 2} ''';' ]);
	end
end

disp('Par�metros encontrados: ');
disp(parametros);

%% Sanitiza par�metros
if parametros.financiamento.parcelas>(12*parametros.anos_simulacao)
	error('GeradorFluxoCaixa: n�mero de parcelas maior que tempo de simula��o escohido');
end

%converte flags para boolean
parametros.adendo_copel = strcmp(parametros.adendo_copel, 'S');
parametros.remover_antigos = strcmp(parametros.remover_antigos, 'S');
parametros.salvar_faturas = strcmp(parametros.salvar_faturas, 'S');

%% Remove arquivos antigos
if parametros.remover_antigos
	warning('off', 'MATLAB:DELETE:FileNotFound'); %ignorar warning
	delete(['../' parametros.arquivos_saida.fluxo_caixa]);
	delete(['../' parametros.arquivos_saida.faturas]);
	warning('on', 'MATLAB:DELETE:FileNotFound'); %reativa warning
end

%% Gera arquivos de faturas e an�lise de viabilidade para as propostas escolhidas (no caso, todas)
propostas = {'proposta0'; 'proposta1'; 'proposta2'; 'proposta3'; 'proposta4'; 'proposta5'};
modalidades = {'convencional'; 'branca'};
% propostas = {'proposta0'};
% modalidades = {'convencional'};



for i = 1:length(propostas)
	proposta = propostas{i};
	for j = 1:length(modalidades)
		modalidade = modalidades{j};
		disp('_____________________________________________________________________________________________');
		disp(['[INFO] Simula��o do sistema de compensa��o <' proposta '>, modalidade <' modalidade '> (' num2str(parametros.anos_simulacao) ' anos)']);
		
		parametros.sistema_compensacao = proposta;
		parametros.modalidade = modalidade;
				
		disp('[INFO] Simulando fluxo de energia');
		faturas = SimuladorFaturas(parametros); %gera os dados das faturas para os N anos
		
		disp('[INFO] Gerando faturas');
		[~, dados] = PostProcessFaturas(faturas, parametros); %p�s processamento das faturas, agrega��o, inclui campos de saldos totais, hist�ricos, etc...
		
		disp('[INFO] Analisando fluxo de caixa');
		GeradorFluxoCaixa(dados, parametros); %gera fluxo de caixa
	end
end

disp('[INFO] Simula��o terminada. Encerrando...');