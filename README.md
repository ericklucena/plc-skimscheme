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