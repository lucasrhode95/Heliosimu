%@TODO: tornar parametros opcional, usando início e fim de ponta hard-coded
function [anos_simu] = SimuladorDemandaGeracao(parametros)
	%carrega dados e inicializa structs temporarárias
	subsetA = xlsread(parametros.excel_pasta_demanda, parametros.excel_planilha_demanda);
	dados_hora = struct();
	ano_amostral = struct();
	qtd_registros = 24*12;
	
	%coleta dados horários do excel
	dados_hora.mes = subsetA(:,1);
	dados_hora.hora = subsetA(:,2);
	dados_hora.demandaMedia = subsetA(:,3);
	dados_hora.geracaoMedia = subsetA(:,4);
	dados_hora.consumo = subsetA(:,5);
	dados_hora.geracao = subsetA(:,6);
	dados_hora.compra = subsetA(:,7);
	dados_hora.venda = subsetA(:,8);
	dados_hora.clocal = subsetA(:,9);
	dados_hora.isPonta = (dados_hora.hora >= parametros.inicio_ponta) & (dados_hora.hora < parametros.fim_ponta);
	dados_hora.isInterm = (dados_hora.hora == parametros.inicio_ponta-1) | (dados_hora.hora == parametros.fim_ponta);
	
	%inicia processo de agregação dos dados
	%note que qualquer grandeza somada em todos os postos  horários
	%necessariamente será igual ao total (seja consumo total, geração
	%total, etc...)
	ano_amostral.consumo.total = zeros(12, 1);
	ano_amostral.consumo.fora = zeros(12, 1);
	ano_amostral.consumo.interm = zeros(12, 1);
	ano_amostral.consumo.ponta = zeros(12, 1);
	
	ano_amostral.geracao.total = zeros(12, 1);
	ano_amostral.geracao.fora = zeros(12, 1);
	ano_amostral.geracao.interm = zeros(12, 1);
	ano_amostral.geracao.ponta = zeros(12, 1);
	
	ano_amostral.compra.total = zeros(12, 1);
	ano_amostral.compra.fora = zeros(12, 1);
	ano_amostral.compra.interm = zeros(12, 1);
	ano_amostral.compra.ponta = zeros(12, 1);
	
	ano_amostral.venda.total = zeros(12, 1);
	ano_amostral.venda.fora = zeros(12, 1);
	ano_amostral.venda.interm = zeros(12, 1);
	ano_amostral.venda.ponta = zeros(12, 1);
	
	ano_amostral.clocal.total = zeros(12, 1);
	ano_amostral.clocal.fora = zeros(12, 1);
	ano_amostral.clocal.interm = zeros(12, 1);
	ano_amostral.clocal.ponta = zeros(12, 1);
	
	for i = 1:qtd_registros
		ano_amostral.consumo.total(dados_hora.mes(i)) = ano_amostral.consumo.total(dados_hora.mes(i)) + dados_hora.consumo(i);
		ano_amostral.geracao.total(dados_hora.mes(i)) = ano_amostral.geracao.total(dados_hora.mes(i)) + dados_hora.geracao(i);
		ano_amostral.compra.total(dados_hora.mes(i)) = ano_amostral.compra.total(dados_hora.mes(i)) + dados_hora.compra(i);
		ano_amostral.venda.total(dados_hora.mes(i)) = ano_amostral.venda.total(dados_hora.mes(i)) + dados_hora.venda(i);
		ano_amostral.clocal.total(dados_hora.mes(i)) = ano_amostral.clocal.total(dados_hora.mes(i)) + dados_hora.clocal(i);
	
		if dados_hora.isPonta(i)
			ano_amostral.consumo.ponta(dados_hora.mes(i)) = ano_amostral.consumo.ponta(dados_hora.mes(i)) + dados_hora.consumo(i);
			ano_amostral.geracao.ponta(dados_hora.mes(i)) = ano_amostral.geracao.ponta(dados_hora.mes(i)) + dados_hora.geracao(i);
			ano_amostral.compra.ponta(dados_hora.mes(i)) = ano_amostral.compra.ponta(dados_hora.mes(i)) + dados_hora.compra(i);
			ano_amostral.venda.ponta(dados_hora.mes(i)) = ano_amostral.venda.ponta(dados_hora.mes(i)) + dados_hora.venda(i);
			ano_amostral.clocal.ponta(dados_hora.mes(i)) = ano_amostral.clocal.ponta(dados_hora.mes(i)) + dados_hora.clocal(i);
		elseif dados_hora.isInterm(i)
			ano_amostral.consumo.interm(dados_hora.mes(i)) = ano_amostral.consumo.interm(dados_hora.mes(i)) + dados_hora.consumo(i);
			ano_amostral.geracao.interm(dados_hora.mes(i)) = ano_amostral.geracao.interm(dados_hora.mes(i)) + dados_hora.geracao(i);
			ano_amostral.compra.interm(dados_hora.mes(i)) = ano_amostral.compra.interm(dados_hora.mes(i)) + dados_hora.compra(i);
			ano_amostral.venda.interm(dados_hora.mes(i)) = ano_amostral.venda.interm(dados_hora.mes(i)) + dados_hora.venda(i);
			ano_amostral.clocal.interm(dados_hora.mes(i)) = ano_amostral.clocal.interm(dados_hora.mes(i)) + dados_hora.clocal(i);
		else
			ano_amostral.consumo.fora(dados_hora.mes(i)) = ano_amostral.consumo.fora(dados_hora.mes(i)) + dados_hora.consumo(i);
			ano_amostral.geracao.fora(dados_hora.mes(i)) = ano_amostral.geracao.fora(dados_hora.mes(i)) + dados_hora.geracao(i);
			ano_amostral.compra.fora(dados_hora.mes(i)) = ano_amostral.compra.fora(dados_hora.mes(i)) + dados_hora.compra(i);
			ano_amostral.venda.fora(dados_hora.mes(i)) = ano_amostral.venda.fora(dados_hora.mes(i)) + dados_hora.venda(i);
			ano_amostral.clocal.fora(dados_hora.mes(i)) = ano_amostral.clocal.fora(dados_hora.mes(i)) + dados_hora.clocal(i);
		end
	end
	
	%calcula parcelas das tarifas (TUSD fio B, fio A, TE, etc,) da
	%modalidade branca utilizando os dados da modalidade convencional. Caso
	%hajam os dados verdadeiros da modalidade branca, isso tudo pode ser
	%removido.
	if strcmp(parametros.modalidade, 'branca')
		ano_amostral.tarifa.fora.total           = parametros.tarifas.branca.fora.total;                                                                                           
		ano_amostral.tarifa.fora.TUSD.total      = parametros.tarifas.branca.fora.TUSD;                                                                                            
		ano_amostral.tarifa.fora.TUSD.encargos   = parametros.tarifas.branca.fora.TUSD*parametros.tarifas.convencional.TUSD.encargos/parametros.tarifas.convencional.TUSD.total;   
		ano_amostral.tarifa.fora.TUSD.fioA       = parametros.tarifas.branca.fora.TUSD*parametros.tarifas.convencional.TUSD.fioA/parametros.tarifas.convencional.TUSD.total;       
		ano_amostral.tarifa.fora.TUSD.fioB       = parametros.tarifas.branca.fora.TUSD*parametros.tarifas.convencional.TUSD.fioB/parametros.tarifas.convencional.TUSD.total;       
		ano_amostral.tarifa.fora.TUSD.perdas     = parametros.tarifas.branca.fora.TUSD*parametros.tarifas.convencional.TUSD.perdas/parametros.tarifas.convencional.TUSD.total;     
		ano_amostral.tarifa.fora.TE.total        = parametros.tarifas.branca.fora.TE;                                                                                              
		ano_amostral.tarifa.fora.TE.encargos     = parametros.tarifas.branca.fora.TE*parametros.tarifas.convencional.TE.encargos/parametros.tarifas.convencional.TE.total;         
		ano_amostral.tarifa.fora.TE.energia      = parametros.tarifas.branca.fora.TE*parametros.tarifas.convencional.TE.energia/parametros.tarifas.convencional.TE.total;          
		ano_amostral.tarifa.fora.TE.fioA         = parametros.tarifas.branca.fora.TE*parametros.tarifas.convencional.TE.fioA/parametros.tarifas.convencional.TE.total;             

		ano_amostral.tarifa.interm.total         = parametros.tarifas.branca.interm.total;                                                                                         
		ano_amostral.tarifa.interm.TUSD.total    = parametros.tarifas.branca.interm.TUSD;                                                                                          
		ano_amostral.tarifa.interm.TUSD.encargos = parametros.tarifas.branca.interm.TUSD*parametros.tarifas.convencional.TUSD.encargos/parametros.tarifas.convencional.TUSD.total; 
		ano_amostral.tarifa.interm.TUSD.fioA     = parametros.tarifas.branca.interm.TUSD*parametros.tarifas.convencional.TUSD.fioA/parametros.tarifas.convencional.TUSD.total;     
		ano_amostral.tarifa.interm.TUSD.fioB     = parametros.tarifas.branca.interm.TUSD*parametros.tarifas.convencional.TUSD.fioB/parametros.tarifas.convencional.TUSD.total;     
		ano_amostral.tarifa.interm.TUSD.perdas   = parametros.tarifas.branca.interm.TUSD*parametros.tarifas.convencional.TUSD.perdas/parametros.tarifas.convencional.TUSD.total;   
		ano_amostral.tarifa.interm.TE.total      = parametros.tarifas.branca.interm.TE;                                                                                            
		ano_amostral.tarifa.interm.TE.encargos   = parametros.tarifas.branca.interm.TE*parametros.tarifas.convencional.TE.encargos/parametros.tarifas.convencional.TE.total;       
		ano_amostral.tarifa.interm.TE.energia    = parametros.tarifas.branca.interm.TE*parametros.tarifas.convencional.TE.energia/parametros.tarifas.convencional.TE.total;        
		ano_amostral.tarifa.interm.TE.fioA       = parametros.tarifas.branca.interm.TE*parametros.tarifas.convencional.TE.fioA/parametros.tarifas.convencional.TE.total;           

		ano_amostral.tarifa.ponta.total          = parametros.tarifas.branca.ponta.total;                                                                                          
		ano_amostral.tarifa.ponta.TUSD.total     = parametros.tarifas.branca.ponta.TUSD;                                                                                           
		ano_amostral.tarifa.ponta.TUSD.encargos  = parametros.tarifas.branca.ponta.TUSD*parametros.tarifas.convencional.TUSD.encargos/parametros.tarifas.convencional.TUSD.total;  
		ano_amostral.tarifa.ponta.TUSD.fioA      = parametros.tarifas.branca.ponta.TUSD*parametros.tarifas.convencional.TUSD.fioA/parametros.tarifas.convencional.TUSD.total;      
		ano_amostral.tarifa.ponta.TUSD.fioB      = parametros.tarifas.branca.ponta.TUSD*parametros.tarifas.convencional.TUSD.fioB/parametros.tarifas.convencional.TUSD.total;      
		ano_amostral.tarifa.ponta.TUSD.perdas    = parametros.tarifas.branca.ponta.TUSD*parametros.tarifas.convencional.TUSD.perdas/parametros.tarifas.convencional.TUSD.total;    
		ano_amostral.tarifa.ponta.TE.total       = parametros.tarifas.branca.ponta.TE;                                                                                             
		ano_amostral.tarifa.ponta.TE.encargos    = parametros.tarifas.branca.ponta.TE*parametros.tarifas.convencional.TE.encargos/parametros.tarifas.convencional.TE.total;        
		ano_amostral.tarifa.ponta.TE.energia     = parametros.tarifas.branca.ponta.TE*parametros.tarifas.convencional.TE.energia/parametros.tarifas.convencional.TE.total;         
		ano_amostral.tarifa.ponta.TE.fioA        = parametros.tarifas.branca.ponta.TE*parametros.tarifas.convencional.TE.fioA/parametros.tarifas.convencional.TE.total;

	else %if convencional, só precisa colocar super-diretório fora, interm e ponta (pra poder usar o mesmo código tanto pra branca quanto pra convencional)
		ano_amostral.tarifa.fora = parametros.tarifas.convencional;
		ano_amostral.tarifa.interm = parametros.tarifas.convencional;
		ano_amostral.tarifa.ponta = parametros.tarifas.convencional;
	end
	
	%aplica impostos.
	impostos                                 = (parametros.ICMS+parametros.PIS+parametros.COFINS)/100;
	ano_amostral.tarifa.fora.total           = ano_amostral.tarifa.fora.total/(1-impostos);           
	ano_amostral.tarifa.fora.TUSD.total      = ano_amostral.tarifa.fora.TUSD.total/(1-impostos);      
	ano_amostral.tarifa.fora.TUSD.encargos   = ano_amostral.tarifa.fora.TUSD.encargos/(1-impostos);   
	ano_amostral.tarifa.fora.TUSD.fioA       = ano_amostral.tarifa.fora.TUSD.fioA/(1-impostos);       
	ano_amostral.tarifa.fora.TUSD.fioB       = ano_amostral.tarifa.fora.TUSD.fioB/(1-impostos);       
	ano_amostral.tarifa.fora.TUSD.perdas     = ano_amostral.tarifa.fora.TUSD.perdas/(1-impostos);     
	ano_amostral.tarifa.fora.TE.total        = ano_amostral.tarifa.fora.TE.total/(1-impostos);        
	ano_amostral.tarifa.fora.TE.encargos     = ano_amostral.tarifa.fora.TE.encargos/(1-impostos);     
	ano_amostral.tarifa.fora.TE.energia      = ano_amostral.tarifa.fora.TE.energia/(1-impostos);      
	ano_amostral.tarifa.fora.TE.fioA         = ano_amostral.tarifa.fora.TE.fioA/(1-impostos);         

	ano_amostral.tarifa.interm.total         = ano_amostral.tarifa.interm.total/(1-impostos);         
	ano_amostral.tarifa.interm.TUSD.total    = ano_amostral.tarifa.interm.TUSD.total/(1-impostos);    
	ano_amostral.tarifa.interm.TUSD.encargos = ano_amostral.tarifa.interm.TUSD.encargos/(1-impostos); 
	ano_amostral.tarifa.interm.TUSD.fioA     = ano_amostral.tarifa.interm.TUSD.fioA/(1-impostos);     
	ano_amostral.tarifa.interm.TUSD.fioB     = ano_amostral.tarifa.interm.TUSD.fioB/(1-impostos);     
	ano_amostral.tarifa.interm.TUSD.perdas   = ano_amostral.tarifa.interm.TUSD.perdas/(1-impostos);   
	ano_amostral.tarifa.interm.TE.total      = ano_amostral.tarifa.interm.TE.total/(1-impostos);      
	ano_amostral.tarifa.interm.TE.encargos   = ano_amostral.tarifa.interm.TE.encargos/(1-impostos);   
	ano_amostral.tarifa.interm.TE.energia    = ano_amostral.tarifa.interm.TE.energia/(1-impostos);    
	ano_amostral.tarifa.interm.TE.fioA       = ano_amostral.tarifa.interm.TE.fioA/(1-impostos);       

	ano_amostral.tarifa.ponta.total          = ano_amostral.tarifa.ponta.total/(1-impostos);          
	ano_amostral.tarifa.ponta.TUSD.total     = ano_amostral.tarifa.ponta.TUSD.total/(1-impostos);     
	ano_amostral.tarifa.ponta.TUSD.encargos  = ano_amostral.tarifa.ponta.TUSD.encargos/(1-impostos);  
	ano_amostral.tarifa.ponta.TUSD.fioA      = ano_amostral.tarifa.ponta.TUSD.fioA/(1-impostos);      
	ano_amostral.tarifa.ponta.TUSD.fioB      = ano_amostral.tarifa.ponta.TUSD.fioB/(1-impostos);      
	ano_amostral.tarifa.ponta.TUSD.perdas    = ano_amostral.tarifa.ponta.TUSD.perdas/(1-impostos);    
	ano_amostral.tarifa.ponta.TE.total       = ano_amostral.tarifa.ponta.TE.total/(1-impostos);       
	ano_amostral.tarifa.ponta.TE.encargos    = ano_amostral.tarifa.ponta.TE.encargos/(1-impostos);    
	ano_amostral.tarifa.ponta.TE.energia     = ano_amostral.tarifa.ponta.TE.energia/(1-impostos);     
	ano_amostral.tarifa.ponta.TE.fioA        = ano_amostral.tarifa.ponta.TE.fioA/(1-impostos);   

	%a partir do ano amostrado, gera os N anos desejados.
	anos_simu = simular_anos(ano_amostral, parametros);
end

function anos_simulados = simular_anos(ano_amostral, parametros)
	%calcula demana líquida do primeiro ano fora do loop
	ano_amostral.demanda_liquida.total = ano_amostral.consumo.total - ano_amostral.geracao.total;
	ano_amostral.demanda_liquida.fora = ano_amostral.consumo.fora - ano_amostral.geracao.fora;
	ano_amostral.demanda_liquida.interm = ano_amostral.consumo.interm - ano_amostral.geracao.interm;
	ano_amostral.demanda_liquida.ponta = ano_amostral.consumo.ponta - ano_amostral.geracao.ponta;
	
	%salva primeiro ano amostral
	anos_simulados = ano_amostral;
	%projeta anos futuros
	for i = 2:parametros.anos_simulacao
		%aumenta as tarifas (rumo natural da inflação)
		parametros.aumento_tarifa = parametros.aumento_tarifa/100;
		ano_amostral.tarifa.fora.total           = ano_amostral.tarifa.fora.total*(1+parametros.aumento_tarifa);           
		ano_amostral.tarifa.fora.TUSD.total      = ano_amostral.tarifa.fora.TUSD.total*(1+parametros.aumento_tarifa);      
		ano_amostral.tarifa.fora.TUSD.encargos   = ano_amostral.tarifa.fora.TUSD.encargos*(1+parametros.aumento_tarifa);   
		ano_amostral.tarifa.fora.TUSD.fioA       = ano_amostral.tarifa.fora.TUSD.fioA*(1+parametros.aumento_tarifa);       
		ano_amostral.tarifa.fora.TUSD.fioB       = ano_amostral.tarifa.fora.TUSD.fioB*(1+parametros.aumento_tarifa);       
		ano_amostral.tarifa.fora.TUSD.perdas     = ano_amostral.tarifa.fora.TUSD.perdas*(1+parametros.aumento_tarifa);     
		ano_amostral.tarifa.fora.TE.total        = ano_amostral.tarifa.fora.TE.total*(1+parametros.aumento_tarifa);        
		ano_amostral.tarifa.fora.TE.encargos     = ano_amostral.tarifa.fora.TE.encargos*(1+parametros.aumento_tarifa);     
		ano_amostral.tarifa.fora.TE.energia      = ano_amostral.tarifa.fora.TE.energia*(1+parametros.aumento_tarifa);      
		ano_amostral.tarifa.fora.TE.fioA         = ano_amostral.tarifa.fora.TE.fioA*(1+parametros.aumento_tarifa);         

		ano_amostral.tarifa.interm.total         = ano_amostral.tarifa.interm.total*(1+parametros.aumento_tarifa);         
		ano_amostral.tarifa.interm.TUSD.total    = ano_amostral.tarifa.interm.TUSD.total*(1+parametros.aumento_tarifa);    
		ano_amostral.tarifa.interm.TUSD.encargos = ano_amostral.tarifa.interm.TUSD.encargos*(1+parametros.aumento_tarifa); 
		ano_amostral.tarifa.interm.TUSD.fioA     = ano_amostral.tarifa.interm.TUSD.fioA*(1+parametros.aumento_tarifa);     
		ano_amostral.tarifa.interm.TUSD.fioB     = ano_amostral.tarifa.interm.TUSD.fioB*(1+parametros.aumento_tarifa);     
		ano_amostral.tarifa.interm.TUSD.perdas   = ano_amostral.tarifa.interm.TUSD.perdas*(1+parametros.aumento_tarifa);   
		ano_amostral.tarifa.interm.TE.total      = ano_amostral.tarifa.interm.TE.total*(1+parametros.aumento_tarifa);      
		ano_amostral.tarifa.interm.TE.encargos   = ano_amostral.tarifa.interm.TE.encargos*(1+parametros.aumento_tarifa);   
		ano_amostral.tarifa.interm.TE.energia    = ano_amostral.tarifa.interm.TE.energia*(1+parametros.aumento_tarifa);    
		ano_amostral.tarifa.interm.TE.fioA       = ano_amostral.tarifa.interm.TE.fioA*(1+parametros.aumento_tarifa);       

		ano_amostral.tarifa.ponta.total          = ano_amostral.tarifa.ponta.total*(1+parametros.aumento_tarifa);          
		ano_amostral.tarifa.ponta.TUSD.total     = ano_amostral.tarifa.ponta.TUSD.total*(1+parametros.aumento_tarifa);     
		ano_amostral.tarifa.ponta.TUSD.encargos  = ano_amostral.tarifa.ponta.TUSD.encargos*(1+parametros.aumento_tarifa);  
		ano_amostral.tarifa.ponta.TUSD.fioA      = ano_amostral.tarifa.ponta.TUSD.fioA*(1+parametros.aumento_tarifa);      
		ano_amostral.tarifa.ponta.TUSD.fioB      = ano_amostral.tarifa.ponta.TUSD.fioB*(1+parametros.aumento_tarifa);      
		ano_amostral.tarifa.ponta.TUSD.perdas    = ano_amostral.tarifa.ponta.TUSD.perdas*(1+parametros.aumento_tarifa);    
		ano_amostral.tarifa.ponta.TE.total       = ano_amostral.tarifa.ponta.TE.total*(1+parametros.aumento_tarifa);       
		ano_amostral.tarifa.ponta.TE.encargos    = ano_amostral.tarifa.ponta.TE.encargos*(1+parametros.aumento_tarifa);    
		ano_amostral.tarifa.ponta.TE.energia     = ano_amostral.tarifa.ponta.TE.energia*(1+parametros.aumento_tarifa);     
		ano_amostral.tarifa.ponta.TE.fioA        = ano_amostral.tarifa.ponta.TE.fioA*(1+parametros.aumento_tarifa);        



		%aumenta o consumo (rumo natural da humanidade)
		ano_amostral.consumo.total = ano_amostral.consumo.total*(1+parametros.aumento_demanda/100);
		ano_amostral.consumo.fora = ano_amostral.consumo.fora*(1+parametros.aumento_demanda/100);
		ano_amostral.consumo.interm = ano_amostral.consumo.interm*(1+parametros.aumento_demanda/100);
		ano_amostral.consumo.ponta = ano_amostral.consumo.ponta*(1+parametros.aumento_demanda/100);
		%diminui a geração (desgaste do painel)
		ano_amostral.geracao.total = ano_amostral.geracao.total*(1-parametros.diminui_geracao/100);
		ano_amostral.geracao.fora = ano_amostral.geracao.fora*(1-parametros.diminui_geracao/100);
		ano_amostral.geracao.interm = ano_amostral.geracao.interm*(1-parametros.diminui_geracao/100);
		ano_amostral.geracao.ponta = ano_amostral.geracao.ponta*(1-parametros.diminui_geracao/100);
		%se aumenta consumo, compra aumenta proporcionalmente
		ano_amostral.compra.total = ano_amostral.compra.total*(1+parametros.aumento_demanda/100);
		ano_amostral.compra.fora = ano_amostral.compra.fora*(1+parametros.aumento_demanda/100);
		ano_amostral.compra.interm = ano_amostral.compra.interm*(1+parametros.aumento_demanda/100);
		ano_amostral.compra.ponta = ano_amostral.compra.ponta*(1+parametros.aumento_demanda/100);
		%se diminui geração, venda diminui proporcionalmente
		ano_amostral.venda.total = ano_amostral.venda.total*(1-parametros.diminui_geracao/100);
		ano_amostral.venda.fora = ano_amostral.venda.fora*(1-parametros.diminui_geracao/100);
		ano_amostral.venda.interm = ano_amostral.venda.interm*(1-parametros.diminui_geracao/100);
		ano_amostral.venda.ponta = ano_amostral.venda.ponta*(1-parametros.diminui_geracao/100);
		%calcula consumo local com base nos valores de demanda - compra
		ano_amostral.clocal.total = ano_amostral.consumo.total - ano_amostral.compra.total;
		ano_amostral.clocal.fora = ano_amostral.consumo.fora - ano_amostral.compra.fora;
		ano_amostral.clocal.interm = ano_amostral.consumo.interm - ano_amostral.compra.interm;
		ano_amostral.clocal.ponta = ano_amostral.consumo.ponta - ano_amostral.compra.ponta;
		%calcula demanda líquida com base no consumo total - geração <<<<
		%isso é o que o medidor enxerga
		ano_amostral.demanda_liquida.total = ano_amostral.consumo.total - ano_amostral.geracao.total;
		ano_amostral.demanda_liquida.fora = ano_amostral.consumo.fora - ano_amostral.geracao.fora;
		ano_amostral.demanda_liquida.interm = ano_amostral.consumo.interm - ano_amostral.geracao.interm;
		ano_amostral.demanda_liquida.ponta = ano_amostral.consumo.ponta - ano_amostral.geracao.ponta;
		
		anos_simulados = [anos_simulados ano_amostral];
	end
end