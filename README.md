SkimScheme
==========

Descrição do projeto: https://sites.google.com/a/cin.ufpe.br/if686/projeto

Para compilar:
> ghc SSInterpreter.hs

Para executar:
Linux	> ./SSInterpreter CODE_STRING
Windows	> SSInterpreter CODE_STRING

Programa teste:

SSInterpreter "(begin (define f (lambda (x) (+ x 10))) (define result (f (car '(50 34 567 433 22 23 2345 \"ok\" (6 87 6))))) result)"


TODO:
	FUNCTIONAL PROGRAMMING, BITCHES. YEAH!

DONE:
	Função condicional (if)	- 4.1.5
	Divisão inteira (/)
	modulo
	Variáveis locais (let)	- 4.2.2
	lt?
	eqv? 					-6.1
	cons
	Atribuição (set!)
	create-struct
	set-attr!
	get-attr
	Chamadas recursivas 	- 4.1.3
	Programas de teste
	Quicksort recursivo