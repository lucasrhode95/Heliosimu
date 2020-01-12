function GeradorFluxoCaixa(faturas, parametros)
%GERADORFLUXOCAIXA Função que gera excel contendo o fluxo de caixa anual
%pra cada proposta
% Algumas taxas % precisam ser convertidas entra anual<->mensal, a formula
% para conversão entre taxas mensais e anuais é:
% mensal = (1+anual)^1/12 - 1
% anual = (1+mensal)^12 - 1

% 	assignin('base', 'dados', dados); %debug

	anos = [0; faturas(:, 1)];
	meses = [0; faturas(:, 2)];
	meses_num = [0; meses(2:end)+12*(anos(2:end)-1)]; %anos desde o começo do período de simulação
	total_sem_painel = [0; faturas(:, 18)];
	total_com_painel = [0; faturas(:, 21)];
	
	entradas = total_sem_painel - total_com_painel;
	custo_total = parametros.custo.equipamento + parametros.custo.instalacao;
	entrada_din = custo_total*parametros.financiamento.entrada/100;
	saldo_devedor = custo_total - entrada_din;
	
	juros_mensal = anual2mensal(parametros.financiamento.juros/100);
	inflacao_mensal = anual2mensal(parametros.inflacao/100);
	reinvestimento_mensal = anual2mensal(parametros.reinvestimento/100);
	
	if saldo_devedor == 0
		num_parcelas = 0;
	else
		num_parcelas = parametros.financiamento.parcelas;
	end
	
	%calcula as saídas (pagamentos do financiamento)
	switch parametros.financiamento.tipo_amortizacao
		case 'price'
			parcelas = (saldo_devedor*(1 + juros_mensal)^num_parcelas*juros_mensal/((1 + juros_mensal)^num_parcelas-1))*ones(num_parcelas, 1);
		case 'sac'
			parcelas = (0:num_parcelas-1)';
			parcelas = saldo_devedor*(1/num_parcelas + juros_mensal*(1 - parcelas./num_parcelas));
		otherwise
			error(['GeradorFluxoCaixa: Amortização tipo <' parametros.financiamento.tipo_amortizacao '> não reconhecida']);
	end
	saidas = [entrada_din; parcelas; zeros(meses_num(end) - num_parcelas, 1)];
	
	%reaplica as entradas a taxa determinada nos parâmetros (só reaplica
	%depois que terminar de terminar o financiamento - óbvio)
	retorno_investimento = entradas(num_parcelas+2:end).*((1 + reinvestimento_mensal).^(meses_num(end) - meses_num(num_parcelas+2:end))-1);
	retorno_investimento = [zeros(num_parcelas+1, 1); retorno_investimento];
	
	%fluxo de caixa líquido
	fluxo_caixa = entradas - saidas + retorno_investimento;
	
	%TIR
	warning('off', 'finance:irr:multipleIRR'); %ignorar warning
	TIR_mensal = irr(fluxo_caixa); %calcula TIR mensal
	TIR_anual = mensal2anual(TIR_mensal); %converte pra anual
	warning('on', 'finance:irr:multipleIRR'); %reativa warning
	
	%VPL
	VPL = pvvar(fluxo_caixa, inflacao_mensal);
	
	%Payback simples
	saldo_acumulado = cumsum(fluxo_caixa);
	for payback_simples = 2:meses_num(end) %começa no 2 pq primeira posição é o mês 0
		if saldo_acumulado(payback_simples) >= 0
			break
		elseif payback_simples == meses_num(end)
			payback_simples = 0;
		end
	end
	payback_simples = payback_simples - 1;
	
	%Payback descontado
	fluxo_caixa_VP = fluxo_caixa./(1 + inflacao_mensal).^meses_num; %valor presente dos fluxos
	saldo_acumulado = cumsum(fluxo_caixa_VP);
	for payback_descontado = 2:meses_num(end)
		if saldo_acumulado(payback_descontado) >= 0
			break
		elseif payback_descontado == meses_num(end)
			payback_descontado = 0;
		end
	end
	payback_descontado = payback_descontado - 1;
	
	%ROI
	ROI = VPL/custo_total;
	
	%prepara a saída de dados
	nome_arquivo = ['../' parametros.arquivos_saida.fluxo_caixa];
	
	payback_simples = mes2str(payback_simples);
	payback_descontado = mes2str(payback_descontado);
	
	switch parametros.sistema_compensacao
		case 'proposta0'
			sistema_compensacao = 'Proposta Aneel #0';
		case 'proposta1'
			sistema_compensacao = 'Proposta Aneel #1';
		case 'proposta2'
			sistema_compensacao = 'Proposta Aneel #2';
		case 'proposta3'
			sistema_compensacao = 'Proposta Aneel #3';
		case 'proposta4'
			sistema_compensacao = 'Proposta Aneel #4';
		case 'proposta5'
			sistema_compensacao = 'Proposta Aneel #5';
		otherwise
			error(['GeradorFluxoCaixa: Sistema de compensação <' parametros.sistema_compensacao '> não reconhecido']);
	end
	
	switch parametros.modalidade
		case 'branca'
			modalidade = 'Tarifa branca';
		case 'convencional'
			modalidade = 'Tarifa convencional';
		otherwise
			error(['GeradorFluxoCaixa: Modalidade tarifaria <' parametros.modalidade '> não reconhecida']);
	end
	
	warning('off', 'MATLAB:xlswrite:AddSheet'); %ignorar warning
	%checa se arquivo já existe
	if exist(nome_arquivo, 'file') == 2
		[~, ~, raw] = xlsread(nome_arquivo, 'Análise de fluxo de caixa');
		linhas = size(raw);
		linhas = linhas(1);
		celula_inicial = ['A' num2str(linhas+1)];
		identificador = linhas;
	else %caso não exista, adiciona cabeçalho
		header =   {'Id',         'Descrição',          'Parcelas',   'Entrada (%)'		'Reinvestimento (%)',      'Disponibilidade (kWh)',    'Juros financiamento (%)',      'Período (anos)',          'Inflação (%)',      'TMA (%)',      'Investimento (R$)', 'Sistema compensação', 'Modalidade', 'Payback simples', 'Payback descontado', 'TIR (%)',       'VPL (R$)', 'ROI (%)', 'Viabilidade'};
		xlswrite(nome_arquivo, header, 'Análise de fluxo de caixa', 'A1');
		celula_inicial = 'A2';
		identificador = 1;
	end
	
	if (TIR_anual*100 < parametros.TMA) || (ROI < 0)
		viabilidade = 'não viável';
	else
		viabilidade = 'viável';
	end
	
	%aqui vou escrevendo os itens do header conforme os itens do vetor
	%<dados>, aí no final copio e colo pra dentro do <else> ali em cima
% 	header =   {'Id',         'Descrição',          'Parcelas',   'Entrada (%)'		                'Reinvestimento (%)',      'Disponibilidade (kWh)',    'Juros financiamento (%)',      'Período (anos)',          'Inflação (%)',      'TMA (%)',      'Investimento (R$)', 'Sistema compensação', 'Modalidade', 'Payback simples', 'Payback descontado', 'TIR (%)',       'VPL (R$)', 'ROI (%)', 'Viabilidade'};
	faturas  = {identificador, parametros.descricao, num_parcelas, parametros.financiamento.entrada, parametros.reinvestimento, parametros.disponibilidade, parametros.financiamento.juros, parametros.anos_simulacao, parametros.inflacao, parametros.TMA, custo_total,         sistema_compensacao,   modalidade,   payback_simples,   payback_descontado,   TIR_anual*100,   VPL,        ROI*100,   viabilidade};
	
	xlswrite(nome_arquivo, faturas, 'Análise de fluxo de caixa', celula_inicial);
	warning('on', 'MATLAB:xlswrite:AddSheet'); %reativa warning
end

function str = mes2str(mes_num)
	str = [num2str(fix(mes_num/12)) ' anos, ' num2str(mes_num - 12*fix(mes_num/12)) ' meses'];
end

function taxa_mensal = anual2mensal(taxa_anual)
	taxa_mensal = (1 + taxa_anual)^(1/12) - 1;
end

function taxa_anual = mensal2anual(taxa_mensal)
	taxa_anual = (1 + taxa_mensal)^(12) - 1;
end