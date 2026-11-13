---
name: Finanças
description: Controle de gastos pessoais em Flutter — cartões brancos sobre cinza suave, tinta preta e um único laranja de alerta.
colors:
  ink: "#0B0B0C"
  canvas: "#F4F4F5"
  card: "#FFFFFF"
  muted: "#8A8A8F"
  faint: "#B4B4B8"
  track: "#EAEAEC"
  accent: "#FF4D0D"
  accent-tint: "#FFEEE6"
  positive: "#16A34A"
  positive-tint: "#E7F6EC"
  warning: "#D97706"
  warning-tint: "#FFF4E0"
typography:
  title:
    fontFamily: "system (Roboto / SF)"
    fontSize: "26px"
    fontWeight: 700
    letterSpacing: "-0.6px"
  big:
    fontFamily: "system (Roboto / SF)"
    fontSize: "34px"
    fontWeight: 600
    letterSpacing: "-1px"
  body:
    fontFamily: "system (Roboto / SF)"
    fontSize: "14px"
    fontWeight: 600
  small:
    fontFamily: "system (Roboto / SF)"
    fontSize: "11.5px"
    fontWeight: 400
  sub:
    fontFamily: "system (Roboto / SF)"
    fontSize: "12px"
    fontWeight: 400
rounded:
  xs: "3px"
  md: "11px"
  lg: "14px"
  xl: "20px"
  sheet: "30px"
  full: "999px"
spacing:
  xs: "8px"
  sm: "10px"
  md: "14px"
  lg: "16px"
  nav-clearance: "120px"
components:
  card:
    backgroundColor: "{colors.card}"
    rounded: "{rounded.xl}"
    padding: "16px"
  txn-row:
    backgroundColor: "{colors.card}"
    rounded: "{rounded.xl}"
    padding: "12px"
  segmented-pill:
    backgroundColor: "{colors.track}"
    rounded: "13px"
    height: "38px"
  pill:
    rounded: "8px"
    padding: "3px 7px"
  fab-add:
    backgroundColor: "{colors.ink}"
    rounded: "{rounded.full}"
    size: "62px"
  button-contribute:
    backgroundColor: "{colors.ink}"
    textColor: "{colors.card}"
    rounded: "10px"
    padding: "7px 12px"
---

# Design System: Finanças

## Overview

**Creative North Star: "O Painel Sereno"**

Cartões brancos pousados sobre um cinza suave, tinta quase preta para o que importa e um único laranja reservado para alerta e ênfase. O app é denso em números, então o calor vem do movimento calmo e do toque macio, não de cor ou ornamento: valores contam de zero até o total, barras crescem, listas entram em cascata.

A hierarquia é tipográfica e numérica. Rótulos cinza pequenos, valores em peso 600–700 com tracking apertado, centavos em cinza claro. Verde significa dinheiro entrando ou meta cumprida; laranja significa gasto, alerta ou progresso de orçamento perto do limite.

**Key Characteristics:**
- Fundo cinza (#F4F4F5) com cartões brancos de cantos grandes (20px).
- Preto como cor de ação; laranja só para alerta e destaque.
- Quase plano: separação por tom, sombras só um sussurro.
- Toque macio: escala ao pressionar, háptico, movimento easeOutCubic.
- Todo texto em português do Brasil; moeda `R$ 1.234,56`.

## Colors

Paleta neutra e fria com um acento quente e dois semânticos.

### Primary
- **Tinta de Jornal** (#0B0B0C): texto principal, botão "+", botão de aporte, item de navegação ativo, barras de progresso padrão.

### Secondary
- **Laranja de Alerta** (#FF4D0D): despesas, alerta de orçamento (≥80%), indicador da aba ativa, "Limpar", percentuais de meta. Fundo suave `#FFEEE6`.

### Tertiary
- **Verde Receita** (#16A34A): receitas, economia positiva, meta concluída. Fundo suave `#E7F6EC`.
- **Âmbar Pendente** (#D97706): estados pendentes; fundo `#FFF4E0`.

### Neutral
- **Névoa** (#F4F4F5): fundo de tela e campos dentro de cartões.
- **Papel** (#FFFFFF): cartões, barra de navegação, folha de lançamento.
- **Cinza Médio** (#8A8A8F): rótulos e subtítulos.
- **Cinza Claro** (#B4B4B8): centavos, itens inativos, linhas guia.
- **Trilho** (#EAEAEC): trilhos de barras de progresso e fundo do controle segmentado.

### Named Rules
**The One Voice Rule.** O laranja aparece em poucos pontos por tela; sua raridade é o que o faz alertar.
**The Money Colors Rule.** Verde = entra, laranja = sai. Nunca inverta nem use os dois para decoração.

## Typography

**Fonte única:** a do sistema (Roboto no Android, SF no iOS), sem família customizada.

**Character:** neutra e funcional; a personalidade vem do peso e do tracking apertado nos números, não da família.

### Hierarchy
- **Title** (700, 26px, tracking −0.6): título de tela.
- **Big** (600, 34px, tracking −1): saldos e totais; centavos em Cinza Claro.
- **Body** (600, 14px): nomes de itens, títulos de cartão, valores de linha (13px em listas).
- **Small** (400, 11.5px, Cinza Médio): rótulos, subtítulos, metadados.
- **Sub** (400, 12px, Cinza Médio): subtítulo do cabeçalho.

### Named Rules
**The Quiet Cents Rule.** Valores monetários usam algarismos tabulares e centavos em Cinza Claro.

## Layout

Lista rolável de coluna única com margem lateral de 16px e espaço inferior de 120px para a barra de navegação flutuante. Cartões separados por 14px; linhas de lista por 8–10px. Cabeçalho (título, subtítulo, sino e +) abre cada aba. A densidade é média: informação por cartão, respiro entre cartões.

## Elevation & Depth

Sistema quase plano. A profundidade vem do contraste tonal entre cartão branco e fundo cinza; os cartões carregam apenas uma sombra ambiente quase imperceptível. Só a barra de navegação e o botão "+" têm sombra de verdade, porque flutuam sobre o conteúdo.

### Shadow Vocabulary
- **Cartão** (`0 6px 18px rgba(0,0,0,0.06)`): cartões e linhas de lista.
- **Barra de navegação** (`0 8px 24px rgba(0,0,0,0.10)`): barra flutuante.
- **Botão +** (`0 6px 16px rgba(0,0,0,0.20)`): ação principal.

### Named Rules
**The Whisper Shadow Rule.** Sombra de cartão nunca passa de 6% de opacidade; só o que flutua ganha sombra marcada.

## Shapes

Cantos generosos e consistentes: cartões 20px, campos 13–14px, ícones em quadrados de 11–12px, pílulas 8px, controle segmentado 13px (miolo 10px), folha de lançamento 30px, barra de navegação 28px, botão "+" circular. Barras de progresso têm 5–6px com raio 3px.

## Components

### Cartão (SoftCard)
- **Shape:** raio 20px, padding 16px (12px em linhas de lista).
- **Background:** Papel (#FFFFFF), largura total.
- **Shadow:** Cartão.

### Linha de transação
- Ícone da categoria em quadrado de 38px (raio 12px, Névoa), título 13px/600, categoria · dia em Small, valor à direita; receita em verde com `+`, despesa em tinta com `−`.
- Escala 0.95 ao pressionar.

### Controle segmentado
- Trilho (#EAEAEC), 38px de altura; miolo branco desliza (easeOutQuart) sob o rótulo ativo (700 vs 500).

### Pílula (Pill)
- Texto 10.5px/600, padding 3×7, raio 8px; pares de cor fg/bg semânticos.

### Barra de progresso
- Trilho cinza, preenchimento tinta (concluído verde, orçamento ≥80% laranja), anima em 900ms easeOutCubic.

### Navegação
- Barra branca flutuante (raio 28px) com 4 abas e botão "+" central de 62px (tinta, borda de 5px na cor do fundo) que gira 45° ao abrir a folha. Aba ativa: ícone ampliado 1.12, rótulo 700, indicador laranja de 14×3px.

### Folha de lançamento (add sheet)
- Folha branca, raio 30px, alça de 36×4px; valor 40px; categorias em chips (ativo tinta, inativo Névoa, raio 19px); teclado numérico; botão de salvar tinta (verde ao salvar), raio 26px.

## Do's and Don'ts

### Do:
- **Do** usar tinta (#0B0B0C) para ação principal e reservar o laranja (#FF4D0D) para despesa e alerta.
- **Do** usar cartões brancos de raio 20px sobre Névoa, com sombra de no máximo 6%.
- **Do** puxar duração e curva de `Motion` (180/320/700ms, easeOutCubic; mola easeOutBack só para escala).
- **Do** formatar moeda como `R$ 1.234,56` e meses/datas em português.
- **Do** dar 44px de alvo de toque a qualquer controle novo.

### Don't:
- **Don't** introduzir uma segunda cor de destaque nem usar verde e laranja de forma decorativa.
- **Don't** adicionar bordas ou divisores em cartões; a separação é tonal.
- **Don't** usar sombras fortes em cartões; elas pertencem à barra de navegação e ao botão "+".
- **Don't** trocar a fonte do sistema por uma família customizada sem decisão explícita.
- **Don't** escrever textos de interface em inglês.
