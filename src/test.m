clear;clc;

%% ENTRADAS
disp('-------------------------------------------------------------');

%             Ponta|Interm|Fora
consumo  = [ 300,   50,   200]; %[kWh] 

creditos = [   0,    0,    50; % creditos que restaram de meses anteriores
		     310,   30,  100]; % créditos gerados no mês atual [kWh]


% ordem que deve ser realizada a compensação
% ordem = [1, 2, 3]
% ordem = [1, 3, 2]
% ordem = [2, 1, 3]
% ordem = [2, 3, 1]
% ordem = [3, 1, 2]
ordem = [3, 2, 1]

tarifas = [0.91974, 0.59690, 0.43568];
TE      = [0.43634, 0.27472, 0.27472];
tarifaConv = 0.50752;
disponibil = 50;

%% PREAMBULO
Zmin = tarifaConv*disponibil;

fprintf('Taxa mínima: %0.4f\n', Zmin);
fprintf('Fatura antes da compensação: %0.4f\n', (tarifas(:)')*consumo(:));

credito = creditos;
E = consumo;

%% O algoritmo a seguir assume que o valor da fatura inicial é maior que a taxa mínima
if (tarifas(:)')*E(:) <= Zmin
	return;
end

%% Compensação no mesmo posto da geração
% primeira compensação é no posto tarifário em que ocorreu a geração
for i = 1:length(ordem)	
	Z = (tarifas(:)')*E(:);
		
	if Z <= Zmin
		break;
	end

	x  = ordem(i);
	y  = ordem(i);

	Cxtotal = sum(credito(:, x));

	dZ = tarifas(1)*E(1) + tarifas(2)*E(2) + tarifas(3)*E(3) - Zmin;

	Cxy = TE(y)/TE(x) * dZ /tarifas(y);
% 		Cx = (tarifas(1)*E(1) + tarifas(2)*E(2) + tarifas(3)*E(3) - Zmin) /tarifas(y);
	S = min(Cxy, Cxtotal);

	S = min(TE(y)/TE(x)*E(y), S);

	E(y) = E(y) - S*TE(x)/TE(y);
	credito = removeCredito(credito, x, S);
end

disp('_____RESULTADO COMPENSAÇÃO MESMO POSTO_____');
fprintf('Fatura depois da compensação no mesmo posto: %0.4f\n', (tarifas(:)')*E(:));
credito
E

%% Compensação em postos diferentes
% caso já tenha se alcançado a taxa mínima, termina a execução, pois o
% algoritmo a seguir assume que o valor da fatura inicial é maior que a
% taxa mínima.
if (tarifas(:)')*E(:) <= Zmin
	return;
end

% segunda compensação é feita usando fator de conversão
Z = (tarifas(:)')*E(:);
for i = 1:length(ordem)	
	if Z <= Zmin
		break;
	end
	
	for j = 1:length(ordem)
		if i == j
			continue;
		end
		
		Z = (tarifas(:)')*E(:);
		
		if Z <= Zmin
			break;
		end

		x  = ordem(i);
		y  = ordem(j);

		Cxtotal = sum(credito(:, x));

		dZ = tarifas(1)*E(1) + tarifas(2)*E(2) + tarifas(3)*E(3) - Zmin;
		
		Cxy = TE(y)/TE(x) * dZ /tarifas(y);
% 		Cx = (tarifas(1)*E(1) + tarifas(2)*E(2) + tarifas(3)*E(3) - Zmin) /tarifas(y);
		S = min(Cxy, Cxtotal);
		
		S = min(TE(y)/TE(x)*E(y), S);

		E(y) = E(y) - S*TE(x)/TE(y);
		credito = removeCredito(credito, x, S);
	end
end

disp('_____RESULTADO COMPENSAÇÃO OUTROS POSTOS_____');
fprintf('Fatura depois da compensação em outros postos: %0.4f\n', (tarifas(:)')*E(:));
credito
E

%% Função auxiliar para "sacar" créditos do banco de créditos
function credito = removeCredito(credito, posto, saque)
% Remove do mes atual e anteriores o crédito utilizado.
%
% Examples:
% antiCredito = [50, 5, 15;
%                25, 0, 33];
%
% novoCredito = removeCredito(antigoCredito, 1, 50) realize "saque" de 35
% créditos no período de crédito 1 (ponta), iniciando pela última linha
% (mês de faturação mais recente). O resultado seria:
%
% novoCredito = [40, 5, 15
%                 0, 0, 33];

	% quantidade de meses para iterar
	[linhas, ~] = size(credito);
	
	for i = linhas:-1:1
		if saque <= 0 % caso não haja valor a ser sacado, para a execução
			break
		end
		
		oldCr = credito(i, posto); % salva quantidade créditos no mês i antes do saque
		credito(i, posto) = credito(i, posto) - min(saque, credito(i, posto)); % realiza o saque
		saque = saque - min(saque, oldCr); % atualiza o restante a ser sacado
	end
end