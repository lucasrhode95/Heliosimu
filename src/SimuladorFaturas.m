function faturas = SimuladorFaturas(parametros)	
%SIMULADORFATURAS gera dados necess�rios para gerar as faturas de energia
%el�trica.
%A sa�da desta fun��o � um vetor de structs contendo os dados necess�rios
%para se gerar as faturas de energia el�trica utilizando a fun��o
%GeradorFaturas. A simula��o dos dados e faturas e a formata��o das
%faturas foram desacopladas baseadas no pr�ncipio MVC, onde o processamento
%dos dados ocorre separadamente da exibi��o dos dados (no caso, escrita em
%Excel)

	%fun��o que simula fluxo de energia (consumo total, local, energia
	% comprada e energia injetada), infla��o, desgaste do painel, etc de
	% acordo com os par�metros definidos.
	anos_simu = SimuladorDemandaGeracao(parametros);
	ano_base = anos_simu(1);

% 		assignin('base', 'ano_base', ano_base); %debug
	
	%calcula fator de aproveitamento dos cr�ditos para a proposta
	%solicitada
	parametros.coef_compensacao = getCoeficienteCompensacao(parametros.sistema_compensacao, ano_base.tarifa);
	
	%calcula os fatores de convers�o entre os postos hor�rios (caso seja
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
%cr�ditos.
%Aqui, a princ�pio, � %o �nico lugar que as diferentes propostas t�m
%influ�ncia.
%Aqui se introduz um erro, pois n�o foi poss�vel obter os valores das
%tarifas TUDS fio A, fio B, etc... da modalidade branca, ent�o se
%realizam estimativas baseadas nos valores das tarifas da modalidade
%convencional. No futuro recomenda-se entrar em contato com a Copel para
%solicitar tais valores de forma a poder implementar um coeficiente de
%compensa��o diferente para cada hor�rio, que certamente alterariam
%os resultados.
%Se utilizou o valor de posto intermedi�rio para tentar, intuitivamente,
%minizar o erro (tava batendo melhor com o v�deo da ANEEL)

	posto = 'interm'; %calcula usando tarifas dos postos fora|interm|ponta
	
	%aqui se removem da tarifa total as componentes n�o compensadas em cada
	%proposta. Perceba que ao n�o se remover nada, fica como est�, com
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
			error(['SimuladorFaturas.getCoeficiente: Sistema de compensa��o <' sistema_compensacao '> n�o reconhecido']);
	end
	
	coef_compensacao = coef_compensacao/tarifa.(posto).total; %finaliza o c�lculo do coeficiente
	
	disp(['[INFO] No sistema de compensa��o ' sistema_compensacao ' o rendimento dos cr�ditos � ' num2str(coef_compensacao*100) '%']);
end

function faturas = gerar_faturas(parametros, anos_simulados)

	%mant�m hist�rico de cr�ditos, faturas, tudo
	creditos = [];
	faturas = [];

	for i = 1:parametros.anos_simulacao
		%extrai dados p ficar mais f�cil de acessar
		ano_atual = anos_simulados(i);
		
		% FIXME: isso est� errado. O valor da fatura m�nima � dado pela
		% tarifa mon�mia * disponibilidade:
		%
		% ano_atual.fatura_minima = ano_atual.tarifa.convencional*parametros.disponibilidade
		%
		ano_atual.fatura_minima = (ano_atual.tarifa.fora.total*(24-(parametros.fim_ponta-parametros.inicio_ponta)-2) ...
									+ ano_atual.tarifa.ponta.total*(parametros.fim_ponta-parametros.inicio_ponta) ...
									+ ano_atual.tarifa.interm.total*2)/24*parametros.disponibilidade;
		consumo_ano = ano_atual.compra;
		credito_ano = ano_atual.venda;
		
		% Realiza compensa��o no mesmo per�odo de faturamento, primeiro
		% desconta o consumo utilizando os cr�ditos do mesmo posto hor�rio,
		% como indicado no Art 7�, inciso XI da resolu��o 482/2012.
		% Como esta estapa da compensa��o n�o depende de resultados
		% anteriores, foi feita de uma vez, para o ano inteiro, aqui.
		%                                                            qual consumo compensar|usando qual cr�dito|fator para levar cr�dito do posto de onde foi gerado para onde ser� consumido 
		%                                                                               V          V              V
		[consumo_ano, credito_ano] =   compensar_mesmo_mes(consumo_ano, credito_ano, 'fora',   'fora',            1);                  
		[consumo_ano, credito_ano] =   compensar_mesmo_mes(consumo_ano, credito_ano, 'interm', 'interm',          1);                  
		[consumo_ano, credito_ano] =   compensar_mesmo_mes(consumo_ano, credito_ano, 'ponta',  'ponta',           1);
		%compensa��es com os cr�ditos que sobraram em outros postos:
		[consumo_ano, credito_ano] =   compensar_mesmo_mes(consumo_ano, credito_ano, 'ponta',  'fora',   parametros.coef_fp); 
		[consumo_ano, credito_ano] =   compensar_mesmo_mes(consumo_ano, credito_ano, 'ponta',  'interm', parametros.coef_pi); 
		[consumo_ano, credito_ano] =   compensar_mesmo_mes(consumo_ano, credito_ano, 'interm', 'fora',   parametros.coef_fi); 
		[consumo_ano, credito_ano] =   compensar_mesmo_mes(consumo_ano, credito_ano, 'interm', 'ponta',  parametros.coef_pi);
		[consumo_ano, credito_ano] =   compensar_mesmo_mes(consumo_ano, credito_ano, 'fora',   'interm', parametros.coef_if);
		[consumo_ano, credito_ano] =   compensar_mesmo_mes(consumo_ano, credito_ano, 'fora',   'ponta',  parametros.coef_pf);
		%atualiza o campo .total e calcula o quanto de cr�ditos foram
		%utilizados na compensa��o dentro do mesmo per�odo de faturamento.
		[consumo_ano, credito_ano, credito_mensal_utilizado] = atualizar_totais(consumo_ano, credito_ano, ano_atual.venda);
		
		% Acima foram realizadas as compensa��es de consumo/gera��o dentro
		% do mesmo per�odo de faturamento, para o ano todo, de uma vez.
		% Agora a compensa��o ser� realizada utilizando cr�ditos de meses
		% anteriores para os casos onde existem d�bitos restantes maiores
		% que a tarifa de disponibilidade, como indicado no Art 7�, inciso
		% V. Isso precisa ser feito m�s � m�s, pois os resultados de hoje
		% influciam na disponibilidade de cr�ditos para os meses futuros.
		for j = 1:12
			%salva cr�ditos do in�cio do per�odo
			creditos_inicio_periodo = creditos;
			%remove cr�ditos vencidos
			[creditos, creditos_vencidos] = rem_creditos_venc(creditos, parametros.validade_creditos, i, j);
			%calcula valor da tarifa, sem utiliza��o dos cr�ditos
			custo_energia_mes = consumo_ano.fora(j)  *ano_atual.tarifa.fora.total ...
							  + consumo_ano.interm(j)*ano_atual.tarifa.interm.total ...
							  + consumo_ano.ponta(j) *ano_atual.tarifa.ponta.total;
			%se fatura j� estiver igual ou menor que a taxa m�nima,
			%adiciona cr�ditos que sobraram naquele m�s ao stack de
			%cr�ditos. Como indicado no inciso XVIII do Artigo 7� da res
			%482/2012, os cr�ditos s�o armazenados em kWh, n�o estando
			%sujeitos �s varia��es tarif�rias.
			%sen�o, tenta compensa com cr�ditos de meses anteriores
			credito_anterior_utilizado = [];
			if custo_energia_mes <= ano_atual.fatura_minima
				creditos = add_creditos_stack(creditos, credito_ano, i, j);
				custo_energia_mes = ano_atual.fatura_minima;
			else
				
				%IMPORTANTE: o c�lculo aqui feito N�O leva em conta a
				%proposta ANEEL vigente.
				%A adi��o dos valores de TUSD FIO A, B, etc... para cada
				%proposta � feita em um segundo momento. Feito assim pois �
				%mais simples e intuitivo calcular custo adicional da
				%proposta em fun��o separada do que em dois lugares
				%diferentes, que seriam na compensa��o dentro do mesmo m�s
				%e depois usando cr�ditos anteriores.
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
			
			%calcula custos da ilumina��o p�blica
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
%NEWFATURA cria estrutura de dados com as informa��es que a resolu��o da
%ANEEL exige que apare�am na fatura e outras informa��es extras, como o
%custo referente ao consumo de energia el�trica caso N�O houvesse
%compensa��o do painel solar.
%Cria estrutura de dados a partir dos fluxo de energia calculado na
%fun��o principal <gerar_faturas>.

	fatura.consumo_real.total  = ano_atual.consumo.total(mes);
	fatura.consumo_real.fora  = ano_atual.consumo.fora(mes);
	fatura.consumo_real.interm  = ano_atual.consumo.interm(mes);
	fatura.consumo_real.ponta  = ano_atual.consumo.ponta(mes);
	
	fatura.consumo_medidor.total  = ano_atual.compra.total(mes); %al�nea c, Inciso XIV, Art. 7� Res. 482/2012
	fatura.consumo_medidor.fora  = ano_atual.compra.fora(mes); %al�nea c, Inciso XIV, Art. 7� Res. 482/2012
	fatura.consumo_medidor.interm  = ano_atual.compra.interm(mes); %al�nea c, Inciso XIV, Art. 7� Res. 482/2012
	fatura.consumo_medidor.ponta  = ano_atual.compra.ponta(mes); %al�nea c, Inciso XIV, Art. 7� Res. 482/2012
	
	fatura.energia_injetada.total = ano_atual.venda.total(mes); %al�nea d, Inciso XIV, Art. 7� Res. 482/2012
	fatura.energia_injetada.fora = ano_atual.venda.fora(mes); %al�nea d, Inciso XIV, Art. 7� Res. 482/2012
	fatura.energia_injetada.interm = ano_atual.venda.interm(mes); %al�nea d, Inciso XIV, Art. 7� Res. 482/2012
	fatura.energia_injetada.ponta = ano_atual.venda.ponta(mes); %al�nea d, Inciso XIV, Art. 7� Res. 482/2012
	
	fatura.creditos_inicio = creditos.inicio_periodo; %al�nea b, Inciso XIV, Art. 7� Res. 482/2012
	fatura.creditos_historico = creditos.historico;  %al�nea h, Inciso XIV, Art. 7� Res. 482/2012
	
	fatura.creditos_utilizado_mes.total = creditos.utilizado_mes_atual.total(mes); %al�nea f, Inciso XIV, Art. 7� Res. 482/2012
	fatura.creditos_utilizado_mes.fora = creditos.utilizado_mes_atual.fora(mes); %al�nea f, Inciso XIV, Art. 7� Res. 482/2012
	fatura.creditos_utilizado_mes.interm = creditos.utilizado_mes_atual.interm(mes); %al�nea f, Inciso XIV, Art. 7� Res. 482/2012
	fatura.creditos_utilizado_mes.ponta = creditos.utilizado_mes_atual.ponta(mes); %al�nea f, Inciso XIV, Art. 7� Res. 482/2012
	
	fatura.creditos_utilizados_meses_anteriores = creditos.utilizado_meses_anteriores; %al�nea f, Inciso XIV, Art. 7� Res. 482/2012
	fatura.creditos_vencidos = creditos.vencidos; %al�nea g, Inciso XIV, Art. 7� Res. 482/2012
	
	%calcula valor da tarifa sem compensa��o
	fatura.valor_energia.sem_painel = ...
		  ano_atual.consumo.fora(mes)  *ano_atual.tarifa.fora.total ...
		+ ano_atual.consumo.interm(mes)*ano_atual.tarifa.interm.total ...
		+ ano_atual.consumo.ponta(mes) *ano_atual.tarifa.ponta.total;
	
	%calcula valor da tarifa com compensa��o
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
				error(['SimuladorFaturas.adicional_proposta_ANEEL: Sistema de compensa��o <' sistema_compensacao '> n�o reconhecido']);
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
% Realiza compensa��o do consumo no mesmo per�odo de faturamento (ou seja,
% sem utilizar cr�ditos anteriores)
	
	consumo_restante = consumo;
	credito_restante = credito;
	
	consumo_restante.(posto_consumo) = max(0, consumo.(posto_consumo) - credito.(posto_geracao)*coef_cred_divi);
	credito_restante.(posto_geracao) = max(0, credito.(posto_geracao) - consumo.(posto_consumo)/(coef_cred_divi));
end

function [consumo_atual, credito_atual, credito_utilizado] = atualizar_totais(consumo_atual, credito_atual, credito_inicial)
% Atualiza totais e calcula cr�dito utilizado na compensa��o dentro do
% mesmo m�s
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
% Ap�s feita a compensa��o dentro do mesmo per�odo de faturamento, esta
% fun��o adicion�ria os cr�ditos restantes (se restar) ao stack de
% cr�ditos.
	credito_temp = struct('ano', 0, 'mes', 0, 'kWh', 0, 'posto_horario', 'fora|interm|ponta');
	
	%separa cr�ditos por posto hor�rio
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
%remove cr�ditos que caducaram
	creditos_out = [];
	creditos_rem = [];
	for i = 1:length(stack)
		idade = 12*(ano - stack(i).ano) + mes - stack(i).mes;
		if idade <= validade          %a igualdade aqui implica que a fun��o deve ser executada ANTES de se buscar os cr�ditos de meses anteriores.
			creditos_out = [creditos_out stack(i)];
		else
			creditos_rem = [creditos_rem stack(i)];
		end
	end
	
% 	creditos_out = creditos_out;
end

function [valor_fatura_compensada, creditos_descontados, credito_utilizado] = usar_creditos_anteriores(valor_fatura_inicial, creditos, ano_atual, parametros)
%calcula valor da fatura descontando dos cr�ditos existentes.
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