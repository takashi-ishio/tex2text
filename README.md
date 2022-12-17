# tex2text.rb 

## English README
[tex2text.rb](tex2text.rb) is a very simple Ruby script to extract plain text from a .tex file.
The script is written in 2007.  It was developed because I would like to apply a grammar checker of Microsoft Word to TeX source files ignoring directives of LaTeX.
As the script process LaTeX directives in an ad-hoc manner, the script may not work for tex files including their own macros.
It has been developed on Ruby 1.8.

Features:
 - Resolve section numbers
 - Resolve citations and figure/table numbers
 - Remove some LaTeX tags including verb, it, emph, a single line footnote, and item
 - Remove comments
 - Remove figures and tables
 - Insert markers represenitng begin/end
 - `-s` option: removing citations and footnote


## Japanese README
[tex2text.rb](tex2text.rb) は，texファイルから plain text を抽出する Ruby スクリプトです．
2007年に，作成中の英語論文の中から本文だけを抜き出して Microsoft Word の文法チェックをかけるという程度の用途を想定して作成しました．
LaTeX 文書としての処理はまじめにやってないので，独自マクロを大量に使う人には向きません．
Ruby 1.8 で書きました．

主な機能は以下の通りです.
 - セクション番号の解決
 - 文献，図表番号の解決
 - LaTeX タグ（verb, it, emph, 1行のfootnote, item など一部）の除去
 - コメントの除去
 - 図表の削除
 - begin/end に対して，対応した文字列を挿入する
 - `-s` オプション: 文献番号, footnote を除去する

利用上の規約は今のところ特にありません．
時間の都合で極めて単純な（"泥臭い"）実装をしています．


## Usage

```
ruby tex2text.rb foo.tex
ruby tex2text.rb -s foo.tex
```


### Example Input

```
\section{Solution Name: Assertion with Aspect}

We propose to use aspects to declare assertion.
\emph{Assertion} consists of an assertion statement, 
preconditions and postconditions\cite{Meyer}. 
```

### Example Output (printed to STDOUT)

```
1 Solution Name: Assertion with Aspect


We propose to use aspects to declare assertion.
Assertion consists of an assertion statement, 
preconditions and postconditions[3]. 
```

