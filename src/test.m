clear;clc;

%% ENTRADAS
disp('-------------------------------------------------------------');

%             Ponta|Interm|Fora
consumo  = [ 300,   50,   200]; %[kWh] 

creditos = [   0,    0,    50; % creditos que restaram de meses anteriores
		     310,   30,  100]; % cr�ditos gerados no m�s atual [kWh]


% ordem que deve ser realizada a compensa��o
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

fprintf('Taxa m�nima: %0.4f\n', Zmin);
fprintf('Fatura antes da compensa��o: %0.4f\n', (tarifas(:)')*consumo(:));

credito = creditos;
E = consumo;

%% O algoritmo a seguir assume que o valor da fatura inicial � maior que a taxa m�nima
if (tarifas(:)')*E(:) <= Zmin
	return;
end

%% Compensa��o no mesmo posto da gera��o
% primeira compensa��o � no posto tarif�rio em que ocorreu a gera��o
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

disp('_____RESULTADO COMPENSA��O MESMO POSTO_____');
fprintf('Fatura depois da compensa��o no mesmo posto: %0.4f\n', (tarifas(:)')*E(:));
credito
E

%% Compensa��o em postos diferentes
% caso j� tenha se alcan�ado a taxa m�nima, termina a execu��o, pois o
% algoritmo a seguir assume que o valor da fatura inicial � maior que a
% taxa m�nima.
if (tarifas(:)')*E(:) <= Zmin
	return;
end

% segunda compensa��o � feita usando fator de convers�o
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

disp('_____RESULTADO COMPENSA��O OUTROS POSTOS_____');
fprintf('Fatura depois da compensa��o em outros postos: %0.4f\n', (tarifas(:)')*E(:));
credito
E

%% Fun��o auxiliar para "sacar" cr�ditos do banco de cr�ditos
function credito = removeCredito(credito, posto, saque)
% Remove do mes atual e anteriores o cr�dito utilizado.
%
% Examples:
% antiCredito = [50, 5, 15;
%                25, 0, 33];
%
% novoCredito = removeCredito(antigoCredito, 1, 50) realize "saque" de 35
% cr�ditos no per�odo de cr�dito 1 (ponta), iniciando pela �ltima linha
% (m�s de fatura��o mais recente). O resultado seria:
%
% novoCredito = [40, 5, 15
%                 0, 0, 33];

	% quantidade de meses para iterar
	[linhas, ~] = size(credito);
	
	for i = linhas:-1:1
		if saque <= 0 % caso n�o haja valor a ser sacado, para a execu��o
			break
		end
		
		oldCr = credito(i, posto); % salva quantidade cr�ditos no m�s i antes do saque
		credito(i, posto) = credito(i, posto) - min(saque, credito(i, posto)); % realiza o saque
		saque = saque - min(saque, oldCr); % atualiza o restante a ser sacado
	end
end