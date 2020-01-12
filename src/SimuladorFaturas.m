function faturas = SimuladorFaturas(parametros)	
%SIMULADORFATURAS gera dados necessários para gerar as faturas de energia
%elétrica.
%A saída desta função é um vetor de structs contendo os dados necessários
%para se gerar as faturas de energia elétrica utilizando a função
%GeradorFaturas. A simulação dos dados e faturas e a formatação das
%faturas foram desacopladas baseadas no príncipio MVC, onde o processamento
%dos dados ocorre separadamente da exibição dos dados (no caso, escrita em
%Excel)

	%função que simula fluxo de energia (consumo total, local, energia
	% comprada e energia injetada), inflação, desgaste do painel, etc de
	% acordo com os parâmetros definidos.
	anos_simu = SimuladorDemandaGeracao(parametros);
	ano_base = anos_simu(1);

% 		assignin('base', 'ano_base', ano_base); %debug
	
	%calcula fator de aproveitamento dos créditos para a proposta
	%solicitada
	parametros.coef_compensacao = getCoeficienteCompensacao(parametros.sistema_compensacao, ano_base.tarifa);
	
	%calcula os fatores de conversão entre os postos horários (caso seja
	%modalidade convencional, tudo = 1
	parametros.coef_fi = ano_base.tarifa.fora.TE.total/ano_base.tarifa.interm.TE.total; %fora para interm
	parametros.coef_fp = ano_base.tarifa.fora.TE.total/ano_base.tarifa.ponta.TE.total; %fora para ponta
	parametros.coef_ip = ano_base.tarifa.interm.TE.total/ano_base.tarifa.ponta.TE.total; %interm para ponta

	parametros.coef_if = 1/parametros.coef_fi; %interm para fora
	parametros.coef_pf = 1/parametros.coef_fp; %ponta para fora
	parametros.coef_pi = 1/parametros.coef_ip; %pora para interm

	faturas = gerar_faturas(parametros, anos_simu);
end

function coef_compensacao = getCoeficienteCompensacao(sistema_compensacao, tarifa)
%GETCOEFICIENTECOMPENSACAO Calcula o coeficiente de aproveitamento dos
%créditos.
%Aqui, a princípio, é %o único lugar que as diferentes propostas têm
%influência.
%Aqui se introduz um erro, pois não foi possível obter os valores das
%tarifas TUDS fio A, fio B, etc... da modalidade branca, então se
%realizam estimativas baseadas nos valores das tarifas da modalidade
%convencional. No futuro recomenda-se entrar em contato com a Copel para
%solicitar tais valores de forma a poder implementar um coeficiente de
%compensação diferente para cada horário, que certamente alterariam
%os resultados.
%Se utilizou o valor de posto intermediário para tentar, intuitivamente,
%minizar o erro (tava batendo melhor com o vídeo da ANEEL)

	posto = 'interm'; %calcula usando tarifas dos postos fora|interm|ponta
	
	%aqui se removem da tarifa total as componentes não compensadas em cada
	%proposta. Perceba que ao não se remover nada, fica como está, com
	%coef_compensacao = 1;
	switch sistema_compensacao
		case 'proposta0'
			coef_compensacao = tarifa.(posto).total;
		case 'proposta1'
			coef_compensacao = tarifa.(posto).total - tarifa.(posto).TUSD.fioB;
		case 'proposta2'
			coef_compensacao = tarifa.(posto).total - tarifa.(posto).TUSD.fioB - tarifa.(posto).TUSD.fioA;
		case 'proposta3'
			coef_compensacao = tarifa.(posto).total - tarifa.(posto).TUSD.fioB - tarifa.(posto).TUSD.fioA - tarifa.(posto).TUSD.encargos;
		case 'proposta4'
			coef_compensacao = tarifa.(posto).total - tarifa.(posto).TUSD.fioB - tarifa.(posto).TUSD.fioA - tarifa.(posto).TUSD.encargos - tarifa.(posto).TUSD.perdas;
		case 'proposta5'
			coef_compensacao = tarifa.(posto).total - tarifa.(posto).TUSD.fioB - tarifa.(posto).TUSD.fioA - tarifa.(posto).TUSD.encargos - tarifa.(posto).TUSD.perdas - tarifa.(posto).TE.encargos;
		otherwise
			error(['SimuladorFaturas.getCoeficiente: Sistema de compensação <' sistema_compensacao '> não reconhecido']);
	end
	
	coef_compensacao = coef_compensacao/tarifa.(posto).total; %finaliza o cálculo do coeficiente
	
	disp(['[INFO] No sistema de compensação ' sistema_compensacao ' o rendimento dos créditos é ' num2str(coef_compensacao*100) '%']);
end

function faturas = gerar_faturas(parametros, anos_simulados)

	%mantém histórico de créditos, faturas, tudo
	creditos = [];
	faturas = [];

	for i = 1:parametros.anos_simulacao
		%extrai dados p ficar mais fácil de acessar
		ano_atual = anos_simulados(i);
		
		% FIXME: isso está errado. O valor da fatura mínima é dado pela
		% tarifa monômia * disponibilidade:
		%
		% ano_atual.fatura_minima = ano_atual.tarifa.convencional*parametros.disponibilidade
		%
		ano_atual.fatura_minima = (ano_atual.tarifa.fora.total*(24-(parametros.fim_ponta-parametros.inicio_ponta)-2) ...
									+ ano_atual.tarifa.ponta.total*(parametros.fim_ponta-parametros.inicio_ponta) ...
									+ ano_atual.tarifa.interm.total*2)/24*parametros.disponibilidade;
		consumo_ano = ano_atual.compra;
		credito_ano = ano_atual.venda;
		
		% Realiza compensação no mesmo período de faturamento, primeiro
		% desconta o consumo utilizando os créditos do mesmo posto horário,
		% como indicado no Art 7°, inciso XI da resolução 482/2012.
		% Como esta estapa da compensação não depende de resultados
		% anteriores, foi feita de uma vez, para o ano inteiro, aqui.
		%                                                            qual consumo compensar|usando qual crédito|fator para levar crédito do posto de onde foi gerado para onde será consumido 
		%                                                                               V          V              V
		[consumo_ano, credito_ano] =   compensar_mesmo_mes(consumo_ano, credito_ano, 'fora',   'fora',            1);                  
		[consumo_ano, credito_ano] =   compensar_mesmo_mes(consumo_ano, credito_ano, 'interm', 'interm',          1);                  
		[consumo_ano, credito_ano] =   compensar_mesmo_mes(consumo_ano, credito_ano, 'ponta',  'ponta',           1);
		%compensações com os créditos que sobraram em outros postos:
		[consumo_ano, credito_ano] =   compensar_mesmo_mes(consumo_ano, credito_ano, 'ponta',  'fora',   parametros.coef_fp); 
		[consumo_ano, credito_ano] =   compensar_mesmo_mes(consumo_ano, credito_ano, 'ponta',  'interm', parametros.coef_pi); 
		[consumo_ano, credito_ano] =   compensar_mesmo_mes(consumo_ano, credito_ano, 'interm', 'fora',   parametros.coef_fi); 
		[consumo_ano, credito_ano] =   compensar_mesmo_mes(consumo_ano, credito_ano, 'interm', 'ponta',  parametros.coef_pi);
		[consumo_ano, credito_ano] =   compensar_mesmo_mes(consumo_ano, credito_ano, 'fora',   'interm', parametros.coef_if);
		[consumo_ano, credito_ano] =   compensar_mesmo_mes(consumo_ano, credito_ano, 'fora',   'ponta',  parametros.coef_pf);
		%atualiza o campo .total e calcula o quanto de créditos foram
		%utilizados na compensação dentro do mesmo período de faturamento.
		[consumo_ano, credito_ano, credito_mensal_utilizado] = atualizar_totais(consumo_ano, credito_ano, ano_atual.venda);
		
		% Acima foram realizadas as compensações de consumo/geração dentro
		% do mesmo período de faturamento, para o ano todo, de uma vez.
		% Agora a compensação será realizada utilizando créditos de meses
		% anteriores para os casos onde existem débitos restantes maiores
		% que a tarifa de disponibilidade, como indicado no Art 7°, inciso
		% V. Isso precisa ser feito mês à mês, pois os resultados de hoje
		% influciam na disponibilidade de créditos para os meses futuros.
		for j = 1:12
			%salva créditos do início do período
			creditos_inicio_periodo = creditos;
			%remove créditos vencidos
			[creditos, creditos_vencidos] = rem_creditos_venc(creditos, parametros.validade_creditos, i, j);
			%calcula valor da tarifa, sem utilização dos créditos
			custo_energia_mes = consumo_ano.fora(j)  *ano_atual.tarifa.fora.total ...
							  + consumo_ano.interm(j)*ano_atual.tarifa.interm.total ...
							  + consumo_ano.ponta(j) *ano_atual.tarifa.ponta.total;
			%se fatura já estiver igual ou menor que a taxa mínima,
			%adiciona créditos que sobraram naquele mês ao stack de
			%créditos. Como indicado no inciso XVIII do Artigo 7° da res
			%482/2012, os créditos são armazenados em kWh, não estando
			%sujeitos às variações tarifárias.
			%senão, tenta compensa com créditos de meses anteriores
			credito_anterior_utilizado = [];
			if custo_energia_mes <= ano_atual.fatura_minima
				creditos = add_creditos_stack(creditos, credito_ano, i, j);
				custo_energia_mes = ano_atual.fatura_minima;
			else
				
				%IMPORTANTE: o cálculo aqui feito NÃO leva em conta a
				%proposta ANEEL vigente.
				%A adição dos valores de TUSD FIO A, B, etc... para cada
				%proposta é feita em um segundo momento. Feito assim pois é
				%mais simples e intuitivo calcular custo adicional da
				%proposta em função separada do que em dois lugares
				%diferentes, que seriam na compensação dentro do mesmo mês
				%e depois usando créditos anteriores.
				[custo_energia_mes, creditos, credito_anterior_utilizado] = usar_creditos_anteriores(custo_energia_mes, creditos, ano_atual, parametros);
			end			
			
			fatura_atual = newFatura(ano_atual, j, custo_energia_mes, ...
				struct(...
					'inicio_periodo', creditos_inicio_periodo, ...
					'historico', creditos, ...
					'utilizado_mes_atual', credito_mensal_utilizado, ...
					'utilizado_meses_anteriores', credito_anterior_utilizado, ...
					'vencidos', creditos_vencidos), ...
					parametros.sistema_compensacao ...
				);
			fatura_atual.ano = i;
			fatura_atual.mes = j;
			
			%%%%%%% ADENDO COPEL REMOVER NO FUTURO - precisa da tarifa
			%%%%%%% atual pra calcular a texa extra da copel
			fatura_atual.tarifa = ano_atual.tarifa;
			%%%%%%% ADENDO COPEL REMOVER NO FUTURO
			
			%calcula custos da iluminação pública
			fatura_atual.iluminacao_publica.sem_painel = fatura_atual.valor_energia.sem_painel*parametros.iluminacao_publica/100;
			fatura_atual.iluminacao_publica.com_painel = fatura_atual.valor_energia.com_painel*parametros.iluminacao_publica/100;
			%adiciona esse valor no valor total da fatura
			fatura_atual.valor_total.sem_painel = fatura_atual.valor_energia.sem_painel + fatura_atual.iluminacao_publica.sem_painel;
			fatura_atual.valor_total.com_painel = fatura_atual.valor_energia.com_painel + fatura_atual.iluminacao_publica.com_painel;
			
			faturas = [faturas fatura_atual];
		end
	end
end

function fatura = newFatura(ano_atual, mes, custo_energia, creditos, sistema_compensacao)
%NEWFATURA cria estrutura de dados com as informações que a resolução da
%ANEEL exige que apareçam na fatura e outras informações extras, como o
%custo referente ao consumo de energia elétrica caso NÃO houvesse
%compensação do painel solar.
%Cria estrutura de dados a partir dos fluxo de energia calculado na
%função principal <gerar_faturas>.

	fatura.consumo_real.total  = ano_atual.consumo.total(mes);
	fatura.consumo_real.fora  = ano_atual.consumo.fora(mes);
	fatura.consumo_real.interm  = ano_atual.consumo.interm(mes);
	fatura.consumo_real.ponta  = ano_atual.consumo.ponta(mes);
	
	fatura.consumo_medidor.total  = ano_atual.compra.total(mes); %alínea c, Inciso XIV, Art. 7° Res. 482/2012
	fatura.consumo_medidor.fora  = ano_atual.compra.fora(mes); %alínea c, Inciso XIV, Art. 7° Res. 482/2012
	fatura.consumo_medidor.interm  = ano_atual.compra.interm(mes); %alínea c, Inciso XIV, Art. 7° Res. 482/2012
	fatura.consumo_medidor.ponta  = ano_atual.compra.ponta(mes); %alínea c, Inciso XIV, Art. 7° Res. 482/2012
	
	fatura.energia_injetada.total = ano_atual.venda.total(mes); %alínea d, Inciso XIV, Art. 7° Res. 482/2012
	fatura.energia_injetada.fora = ano_atual.venda.fora(mes); %alínea d, Inciso XIV, Art. 7° Res. 482/2012
	fatura.energia_injetada.interm = ano_atual.venda.interm(mes); %alínea d, Inciso XIV, Art. 7° Res. 482/2012
	fatura.energia_injetada.ponta = ano_atual.venda.ponta(mes); %alínea d, Inciso XIV, Art. 7° Res. 482/2012
	
	fatura.creditos_inicio = creditos.inicio_periodo; %alínea b, Inciso XIV, Art. 7° Res. 482/2012
	fatura.creditos_historico = creditos.historico;  %alínea h, Inciso XIV, Art. 7° Res. 482/2012
	
	fatura.creditos_utilizado_mes.total = creditos.utilizado_mes_atual.total(mes); %alínea f, Inciso XIV, Art. 7° Res. 482/2012
	fatura.creditos_utilizado_mes.fora = creditos.utilizado_mes_atual.fora(mes); %alínea f, Inciso XIV, Art. 7° Res. 482/2012
	fatura.creditos_utilizado_mes.interm = creditos.utilizado_mes_atual.interm(mes); %alínea f, Inciso XIV, Art. 7° Res. 482/2012
	fatura.creditos_utilizado_mes.ponta = creditos.utilizado_mes_atual.ponta(mes); %alínea f, Inciso XIV, Art. 7° Res. 482/2012
	
	fatura.creditos_utilizados_meses_anteriores = creditos.utilizado_meses_anteriores; %alínea f, Inciso XIV, Art. 7° Res. 482/2012
	fatura.creditos_vencidos = creditos.vencidos; %alínea g, Inciso XIV, Art. 7° Res. 482/2012
	
	%calcula valor da tarifa sem compensação
	fatura.valor_energia.sem_painel = ...
		  ano_atual.consumo.fora(mes)  *ano_atual.tarifa.fora.total ...
		+ ano_atual.consumo.interm(mes)*ano_atual.tarifa.interm.total ...
		+ ano_atual.consumo.ponta(mes) *ano_atual.tarifa.ponta.total;
	
	%calcula valor da tarifa com compensação
	fatura.valor_energia.com_painel = custo_energia + adicional_proposta_ANEEL(fatura, ano_atual, sistema_compensacao);
end

function custo_adicional = adicional_proposta_ANEEL(fatura, ano_atual, sistema_compensacao)
	postos = {'fora', 'interm', 'ponta'};
	
	for i = 1:3
		switch sistema_compensacao
			case 'proposta0'
				tarifa_compensacao.(postos{i}) = 0;
			case 'proposta1'
				tarifa_compensacao.(postos{i}) = ano_atual.tarifa.(postos{i}).TUSD.fioB;
			case 'proposta2'
				tarifa_compensacao.(postos{i}) = ano_atual.tarifa.(postos{i}).TUSD.fioB ...
											   + ano_atual.tarifa.(postos{i}).TUSD.fioA;
			case 'proposta3'
				tarifa_compensacao.(postos{i}) = ano_atual.tarifa.(postos{i}).TUSD.fioB ...
											   + ano_atual.tarifa.(postos{i}).TUSD.fioA ...
											   + ano_atual.tarifa.(postos{i}).TUSD.encargos;
			case 'proposta4'
				tarifa_compensacao.(postos{i}) = ano_atual.tarifa.(postos{i}).TUSD.fioB ...
											   + ano_atual.tarifa.(postos{i}).TUSD.fioA ...
											   + ano_atual.tarifa.(postos{i}).TUSD.encargos ...
											   + ano_atual.tarifa.(postos{i}).TUSD.perdas;
			case 'proposta5'
				tarifa_compensacao.(postos{i}) = ano_atual.tarifa.(postos{i}).TUSD.fioB ...
											   + ano_atual.tarifa.(postos{i}).TUSD.fioA ...
											   + ano_atual.tarifa.(postos{i}).TUSD.encargos ...
											   + ano_atual.tarifa.(postos{i}).TUSD.perdas ...
											   + ano_atual.tarifa.(postos{i}).TE.encargos;
			otherwise
				error(['SimuladorFaturas.adicional_proposta_ANEEL: Sistema de compensação <' sistema_compensacao '> não reconhecido']);
		end
	end
	
	custo_adicional = 0;
	for i = 1:3
		try
			credito_utilizado_dummy = fatura.creditos_utilizado_mes.(postos{i});
		catch e
			if strcmp(e.identifier, 'MATLAB:structRefFromNonStruct')
				credito_utilizado_dummy = 0;
			else
				rethrow(ME);
			end
		end
		try
			credito_utilizado_dummy = credito_utilizado_dummy + fatura.creditos_utilizados_meses_anteriores.(postos{i});
		catch e
			if strcmp(e.identifier, 'MATLAB:structRefFromNonStruct')
				%do nothing
			else
				rethrow(ME);
			end
		end
		
		custo_adicional =  custo_adicional + credito_utilizado_dummy*tarifa_compensacao.(postos{i});
	end
end

function [consumo_restante, credito_restante] = compensar_mesmo_mes(consumo, credito, posto_consumo, posto_geracao, coef_cred_divi)
% Realiza compensação do consumo no mesmo período de faturamento (ou seja,
% sem utilizar créditos anteriores)
	
	consumo_restante = consumo;
	credito_restante = credito;
	
	consumo_restante.(posto_consumo) = max(0, consumo.(posto_consumo) - credito.(posto_geracao)*coef_cred_divi);
	credito_restante.(posto_geracao) = max(0, credito.(posto_geracao) - consumo.(posto_consumo)/(coef_cred_divi));
end

function [consumo_atual, credito_atual, credito_utilizado] = atualizar_totais(consumo_atual, credito_atual, credito_inicial)
% Atualiza totais e calcula crédito utilizado na compensação dentro do
% mesmo mês
	consumo_atual.total = zeros(size(consumo_atual.total));
	credito_atual.total = zeros(size(credito_atual.total));
	credito_utilizado   = credito_atual;
	
	posto = {'fora' 'interm'  'ponta'};
	
	for i = 1:length(posto)
		consumo_atual.total  = consumo_atual.total + consumo_atual.(posto{i});
		credito_atual.total  = credito_atual.total + credito_atual.(posto{i});
		credito_utilizado.(posto{i}) = credito_inicial.(posto{i}) - credito_atual.(posto{i});
	end
	
	credito_utilizado.total = credito_inicial.total - credito_atual.total;
end

function creditos_out = add_creditos_stack(stack, credito_anual, ano, mes)
% Após feita a compensação dentro do mesmo período de faturamento, esta
% função adicionária os créditos restantes (se restar) ao stack de
% créditos.
	credito_temp = struct('ano', 0, 'mes', 0, 'kWh', 0, 'posto_horario', 'fora|interm|ponta');
	
	%separa créditos por posto horário
	if credito_anual.fora(mes) > 0
		credito_temp.ano = ano;
		credito_temp.mes = mes;
		credito_temp.kWh = credito_anual.fora(mes);
		credito_temp.posto_horario = 'fora';
		stack = [stack credito_temp];
	end
	if credito_anual.interm(mes) > 0
		credito_temp.ano = ano;
		credito_temp.mes = mes;
		credito_temp.kWh = credito_anual.interm(mes);
		credito_temp.posto_horario = 'interm';
		stack = [stack credito_temp];
	end
	if credito_anual.ponta(mes) > 0
		credito_temp.ano = ano;
		credito_temp.mes = mes;
		credito_temp.kWh = credito_anual.ponta(mes);
		credito_temp.posto_horario = 'ponta';
		stack = [stack credito_temp];
	end
	
	creditos_out = stack;
end

function [creditos_out, creditos_rem] = rem_creditos_venc(stack, validade, ano, mes)
%remove créditos que caducaram
	creditos_out = [];
	creditos_rem = [];
	for i = 1:length(stack)
		idade = 12*(ano - stack(i).ano) + mes - stack(i).mes;
		if idade <= validade          %a igualdade aqui implica que a função deve ser executada ANTES de se buscar os créditos de meses anteriores.
			creditos_out = [creditos_out stack(i)];
		else
			creditos_rem = [creditos_rem stack(i)];
		end
	end
	
% 	creditos_out = creditos_out;
end

function [valor_fatura_compensada, creditos_descontados, credito_utilizado] = usar_creditos_anteriores(valor_fatura_inicial, creditos, ano_atual, parametros)
%calcula valor da fatura descontando dos créditos existentes.
	fatura_minima = ano_atual.fatura_minima;
	tarifa = ano_atual.tarifa;
	valor_fatura_compensada = valor_fatura_inicial;
	credito_utilizado = struct('total', 0, 'ponta', 0, 'interm', 0, 'fora', 0);
% 	struct2table(creditos)
	resta_compensar = max(0, valor_fatura_inicial - fatura_minima);
	for i = 1:length(creditos)
		if (resta_compensar <= 0) break; end
		
		resta_compensar_t = resta_compensar;
		resta_compensar = max(0, resta_compensar - creditos(i).kWh*tarifa.(creditos(i).posto_horario).total);
		creditos(i).kWh = creditos(i).kWh - (resta_compensar_t - resta_compensar)/(tarifa.(creditos(i).posto_horario).total);
		
		credito_utilizado.(creditos(i).posto_horario) = credito_utilizado.(creditos(i).posto_horario) + (resta_compensar_t - resta_compensar)/(tarifa.(creditos(i).posto_horario).total);
		credito_utilizado.total = credito_utilizado.total + (resta_compensar_t - resta_compensar)/(tarifa.(creditos(i).posto_horario).total);
		
		valor_fatura_compensada = fatura_minima + resta_compensar;
	end
	
	creditos_descontados = [];
	for credito = creditos
		if credito.kWh > 0
			creditos_descontados = [creditos_descontados credito];
		end
	end
end