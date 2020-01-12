function controller_varios_testes
	clear; clc;
	addpath('../');
	
	global simulacao_atual; %usada para exibir progresso
	global dummy_mode_on; %modo dummy, não simula nada, só para testar a variação dos parâmetros
	simulacao_atual = 0;
	dummy_mode_on = false;
	
	global propostas; %lista de propostas
	global modalidades; %lista de modalidades
	global disponibilidades; %lista de disponibilidades
	global parcelas; %lista de quantidades de parcelas
	global reinvestimentos; %lista de taxas de reinvestimento
	global entradas; %lista de percentuais de entradas
	global sac_price; %lista de formas de parcelamento
	
% 	propostas = {'proposta0'};
	propostas = {'proposta0'; 'proposta1'; 'proposta2'; 'proposta3'; 'proposta4'; 'proposta5'};
	
% 	modalidades = {'convencional'};
	modalidades = {'convencional', 'branca'};
	
	disponibilidades = 100;
% 	disponibilidades = [30, 50, 100];

% 	parcelas = 0;
	parcelas = [0 6 24 36];

	reinvestimentos = 0;
% 	reinvestimentos = [0 7.9];

% 	entradas = 0;
	entradas = [0 20];
	
	sac_price = {'sac'};
% 	sac_price = {'sac', 'price'};

%% Lê parâmetros definidos no arquivo de parâmetros
	disp('[INFO] Carregando parâmetros...');

	%fonte de dados
	parametros.arquivo_parametros = 'PARAMETROS.xlsx';
	[~, ~, raw]= xlsread(parametros.arquivo_parametros, 'Sheet1');

	[num_parametros, ~] = size(raw);
	for i = 1:num_parametros
		valor_parametro = raw{i, 2};
		if isnumeric(valor_parametro)
			eval(['parametros.' raw{i, 1} ' = ' num2str(raw{i, 2}) ';']);
		else		
			eval(['parametros.' raw{i, 1} ' = ''' raw{i, 2} ''';' ]);
		end
	end

	disp('Parâmetros encontrados: ');
	disp(parametros);

%% Sanitiza parâmetros
	if parametros.financiamento.parcelas>(12*parametros.anos_simulacao)
		error('GeradorFluxoCaixa: número de parcelas maior que tempo de simulação escohido');
	end

	%converte flags para boolean
	parametros.adendo_copel = strcmp(parametros.adendo_copel, 'S');
	parametros.remover_antigos = strcmp(parametros.remover_antigos, 'S');
	
	%como é execução AUTO, não faz sentido manter arquivo de faturas
	parametros.salvar_faturas = false;

%% Remove arquivos antigos
	if parametros.remover_antigos
		warning('off', 'MATLAB:DELETE:FileNotFound'); %ignorar warning
		delete(['../' parametros.arquivos_saida.fluxo_caixa]);
		delete(['../' parametros.arquivos_saida.faturas]);
		warning('on', 'MATLAB:DELETE:FileNotFound'); %reativa warning
	end
	
%% Gera arquivos de faturas e análise de viabilidade para as propostas escolhidas (no caso, todas)
	for  i = 1:length(sac_price)
		tipo_amortizacao = sac_price{i};
		
		parametros.financiamento.tipo_amortizacao = tipo_amortizacao;
		for entrada = entradas
			entrada_original = entrada; %converte % para dinheiro
			for disponibilidade = disponibilidades
				for reinvestimento = reinvestimentos
					for num_parcelas = parcelas
						if num_parcelas == 0
							parametros.financiamento.entrada = 100;
						else
							parametros.financiamento.entrada = entrada_original;
						end
						parametros.financiamento.parcelas = num_parcelas;
						parametros.reinvestimento = reinvestimento;
						parametros.disponibilidade = disponibilidade;
						
						gerar_simulacao(parametros);
					end
				end
			end
		end
	end

	disp('__________________________________________________________________________');
	fprintf('[INFO] Simulação "%s" terminada. Encerrando...\n', get_descricao());
end

%% Função que realmente gera os resultados
function gerar_simulacao(parametros)
	global simulacao_atual; %usada para exibir progresso
	global dummy_mode_on; %modo dummy, não simula nada, só para testar a variação dos parâmetros
	
	global propostas; %lista de propostas
	global modalidades; %lista de modalidades
	global disponibilidades; %lista de disponibilidades
	global parcelas; %lista de quantidades de parcelas
	global reinvestimentos; %lista de taxas de reinvestimento
	global entradas; %lista de percentuais de entradas
	global sac_price; %lista de formas de parcelamento

	total_simulacoes = ...
		length(sac_price)* ...
		length(entradas)* ...
		length(disponibilidades)* ...
		length(reinvestimentos)* ...
		length(parcelas)* ...
		length(propostas)* ...
		length(modalidades);
	
	for i = 1:length(propostas)
		proposta = propostas{i};
		for j = 1:length(modalidades)
			modalidade = modalidades{j};
			
			disp('__________________________________________________________________________');
			disp(['[INFO] Progresso: ' num2str(round(100*simulacao_atual/total_simulacoes, 1)) '%' ' (' num2str(simulacao_atual+1) '/' num2str(total_simulacoes) ')']);
			disp(['[INFO] Simulação do sistema de compensação <' proposta '>, modalidade <' modalidade '> (' num2str(parametros.anos_simulacao) ' anos)']);
			
			parametros.sistema_compensacao = proposta;
			parametros.modalidade = modalidade;
			parametros.descricao = get_descricao(parametros);
			
			if ~dummy_mode_on %modo dummy, não simula nada, só para testar a variação dos parâmetros
				disp('[INFO] Simulando fluxo de energia');
				faturas = SimuladorFaturas(parametros); %gera os dados das faturas para os N anos

				disp('[INFO] Gerando faturas');
				[~, dados] = PostProcessFaturas(faturas, parametros); %pós processamento das faturas, agregação, inclui campos de saldos totais, históricos, etc...

				disp('[INFO] Analisando fluxo de caixa');
				GeradorFluxoCaixa(dados, parametros); %gera fluxo de caixa
			end
			
			simulacao_atual = simulacao_atual + 1;
			disp('[INFO] Iteração concluída');
		end
	end
end

function descricao = get_descricao(parametros)
% 	global descricao_original;
	
% 	if isempty(descricao_original)
		descricao_original = parametros.descricao;
% 	end
	
	descricao = descricao_original;
% 	descricao = [descricao_original ' - ' parametros.financiamento.tipo_amortizacao];
end