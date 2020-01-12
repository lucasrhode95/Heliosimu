function [header, dados] = PostProcessFaturas(faturas, parametros)
% 	assignin('base', 'faturas', faturas); %debug

	ano = [faturas.ano]';
	mes = [faturas.mes]';
	
	temp = [faturas.consumo_real];
	consumo_fora = [temp.fora]';
	consumo_interm = [temp.interm]';
	consumo_ponta = [temp.ponta]';
	
	temp = [faturas.consumo_medidor];
	compra_fora = [temp.fora]';
	compra_interm = [temp.interm]';
	compra_ponta = [temp.ponta]';
	
	temp = [faturas.energia_injetada];	
	venda_fora = [temp.fora]';
	venda_interm = [temp.interm]';
	venda_ponta = [temp.ponta]';
	
	temp = [faturas.valor_energia];
	energia_com_painel = [temp.com_painel]';
	energia_sem_painel = [temp.sem_painel]';
	
	temp = [faturas.iluminacao_publica];
	iluminacao_com_painel = [temp.com_painel]';
	iluminacao_sem_painel = [temp.sem_painel]';
	
	temp = [faturas.valor_total];
	valor_total_com_painel = [temp.com_painel]';
	valor_total_sem_painel = [temp.sem_painel]';
	
	%%%% FUNÇÃO TÁ COM GAMBIARRA PRA RETORNAR O VALOR DA TAXA EXTRA DA
	%%%% COPEL PQ ERA MAIS FÁCIL IMPLEMENTAR AQUI.
	[taxa_extra_copel, saldo_creditos_fora, saldo_creditos_interm, saldo_creditos_ponta, creditos_vencidos] = agregar_creditos(faturas, parametros);
	valor_total_com_painel = valor_total_com_painel + taxa_extra_copel;
	
	%%%%%%%%%            ADENDO PARA COPEL            %%%%%%% adiciona uma coluna a mais para mostrar a parcela extra 
	%%%%%%%%%            REMOVER NO FUTURO            %%%%%%%
	dados = [  ano   mes         compra_fora                    compra_interm                  compra_ponta                  venda_fora             venda_interm             venda_ponta              consumo_fora            consumo_interm                  consumo_ponta               saldo_creditos_fora        saldo_creditos_interm            saldo_creditos_ponta              creditos_vencidos             energia_sem_painel                  iluminacao_sem_painel               valor_total_sem_painel             energia_com_painel              iluminacao_com_painel         valor_total_com_painel];
	header = {'Ano' 'Mês' 'Consumo medidor (fora, kWh)' 'Consumo medidor (interm, kWh)' 'Consumo medidor (ponta, kWh)'  'Injetado (fora, kWh)' 'Injetado (interm, kWh)' 'Injetado (ponta, kWh)' 'Consumo real (fora, kWh)' 'Consumo real (interm, kWh)' 'Consumo real (ponta, kWh)' 'Saldo créditos (fora, kWh)' 'Saldo créditos (interm, kWh)' 'Saldo créditos (ponta, kWh)' 'Créditos vencidos (kWh)' 'Valor consumo (sem painel, R$)' 'Iluminação pública (sem painel, R$)' 'Total fatura (sem painel, R$)' 'Custo consumo (com painel, R$)' 'Iluminação pública (com painel, R$)' 'Total fatura (com painel, R$)'};
	if parametros.adendo_copel
		header = [header 'Extra Copel (com painel, R$)'];
		dados = [dados taxa_extra_copel];
	end
	
	if parametros.salvar_faturas
		warning('off', 'MATLAB:xlswrite:AddSheet'); %ignorar warning
		xlswrite(['../' parametros.arquivos_saida.faturas], header, [parametros.sistema_compensacao ' - ' parametros.modalidade], 'A1');
		xlswrite(['../' parametros.arquivos_saida.faturas], dados, [parametros.sistema_compensacao ' - ' parametros.modalidade], 'A2');
		warning('on', 'MATLAB:xlswrite:AddSheet'); %reativa warning
	end
end

function [taxa_extra_copel, saldo_creditos_fora, saldo_creditos_interm, saldo_creditos_ponta, creditos_vencidos] = agregar_creditos(faturas, parametros)
	%%%% FUNÇÃO TÁ COM GAMBIARRA PRA RETORNAR O VALOR DA TAXA EXTRA DA
	%%%% COPEL PQ ERA MAIS FÁCIL IMPLEMENTAR AQUI
	%%%% NO FUTURO DA PRA REMOVER ISSO V
	taxa_extra_copel = zeros(length(faturas), 1);
	
	fluxo_creditos_fora = zeros(length(faturas), 1);
	fluxo_creditos_interm = zeros(length(faturas), 1);
	fluxo_creditos_ponta = zeros(length(faturas), 1);
	%%%% NO FUTURO DA PRA REMOVER ISSO ^
	%%%% FUNÇÃO TÁ COM GAMBIARRA PRA RETORNAR O VALOR DA TAXA EXTRA DA
	%%%% COPEL PQ ERA MAIS FÁCIL IMPLEMENTAR AQUI
	
	creditos_vencidos = zeros(length(faturas), 1);
	saldo_creditos_fora = zeros(length(faturas), 1);
	saldo_creditos_interm = zeros(length(faturas), 1);
	saldo_creditos_ponta = zeros(length(faturas), 1);
	
	for i = 1:length(faturas)
		%%%% FUNÇÃO TÁ COM GAMBIARRA PRA RETORNAR O VALOR DA TAXA EXTRA DA
		%%%% COPEL PQ ERA MAIS FÁCIL IMPLEMENTAR AQUI
		%%%% NO FUTURO DA PRA REMOVER ISSO V		
		%contabiliza crédito utilizado dentro do mesmo mes
		if ~isempty(faturas(i).creditos_utilizado_mes)
			fluxo_creditos_fora(i) = fluxo_creditos_fora(i) + faturas(i).creditos_utilizado_mes.fora;
			fluxo_creditos_interm(i) = fluxo_creditos_interm(i) + faturas(i).creditos_utilizado_mes.interm;
			fluxo_creditos_ponta(i) = fluxo_creditos_ponta(i) + faturas(i).creditos_utilizado_mes.ponta;
		end
		%contabiliza crédito compensado de meses anteriores
		if ~isempty(faturas(i).creditos_utilizados_meses_anteriores)
			fluxo_creditos_fora(i) = fluxo_creditos_fora(i) + faturas(i).creditos_utilizados_meses_anteriores.fora;
			fluxo_creditos_interm(i) = fluxo_creditos_interm(i) + faturas(i).creditos_utilizados_meses_anteriores.interm;
			fluxo_creditos_ponta(i) = fluxo_creditos_ponta(i) + faturas(i).creditos_utilizados_meses_anteriores.ponta;
		end
		
		if parametros.adendo_copel && strcmp(parametros.sistema_compensacao, 'proposta0')
			taxa_extra_copel(i) = faturas(i).tarifa.fora.TUSD.total*(1/(1-parametros.ICMS/100) - 1)*fluxo_creditos_fora(i);
			taxa_extra_copel(i) = taxa_extra_copel(i) + faturas(i).tarifa.interm.TUSD.total*(1/(1-parametros.ICMS/100) - 1)*fluxo_creditos_interm(i);
			taxa_extra_copel(i) = taxa_extra_copel(i) + faturas(i).tarifa.ponta.TUSD.total*(1/(1-parametros.ICMS/100) - 1)*fluxo_creditos_ponta(i);
		end
		%%%% NO FUTURO DA PRA REMOVER ISSO ^
		%%%% FUNÇÃO TÁ COM GAMBIARRA PRA RETORNAR O VALOR DA TAXA EXTRA DA
		%%%% COPEL PQ ERA MAIS FÁCIL IMPLEMENTAR AQUI
		
		if ~isempty([faturas(i).creditos_vencidos])
			creditos_vencidos(i) = sum([faturas(i).creditos_vencidos.kWh]);
		end
		
		for credito = faturas(i).creditos_historico
			switch credito.posto_horario
				case 'fora'
					saldo_creditos_fora(i) = saldo_creditos_fora(i) + credito.kWh;
				case 'interm'
					saldo_creditos_interm(i) = saldo_creditos_interm(i) + credito.kWh;
				case 'ponta'
					saldo_creditos_ponta(i) = saldo_creditos_ponta(i) + credito.kWh;
				otherwise
					error(['GeradorFaturas.agregar_creditos: Posto horário <' credito.posto_horario '> não reconhecido']);
			end
		end
	end
	
end
