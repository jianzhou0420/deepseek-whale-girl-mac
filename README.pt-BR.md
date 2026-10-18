# 🐋 WhaleBalance · a baleia do saldo DeepSeek para macOS

[简体中文](README.md) · [English](README.en.md) · [繁體中文](README.zh-TW.md) · [日本語](README.ja.md) · [한국어](README.ko.md) · [Español](README.es.md) · [Français](README.fr.md) · [Deutsch](README.de.md) · **Português** · [Русский](README.ru.md)

Uma garota-baleia do DeepSeek que mora num canto da tela do seu Mac. O balão dela mostra seu saldo no DeepSeek, o gasto de hoje e uma contagem regressiva até a próxima troca entre horário de pico e fora de pico. É uma versão nativa para Mac do [widget de saldo do DSH](https://github.com/MeteorNOX/DeepSeek-Balance-Whale-Widget) e não precisa do DeepSeek Harness.

![Prévia](docs/preview.png)

> Este é um projeto de fãs não oficial. Não tem vínculo com o DeepSeek nem é endossado por ele.

## Recursos

- **Saldo**: consulta seu saldo no DeepSeek com sua chave de API, atualiza a cada 60 segundos e quando você clica nela. Saldo total, bônus e saldo recarregado podem aparecer separados.
- **Gasto de hoje**: soma as quedas de saldo como gasto. Recargas são registradas à parte e nunca anulam o gasto, e você pode corrigir qualquer dia à mão. Cada chave de API tem seu próprio livro.
- **Janela de contas**: hoje, últimos 7 dias ou todo o histórico, com detalhes por lançamento, busca por data ou modelo e divisão do gasto.
- **Pico / fora de pico**: dias úteis das 9 às 12 e das 14 às 18 (horário de Pequim) são pico; fins de semana e feriados chineses são fora de pico o dia todo. Cinco estilos de exibição, incluindo contagem regressiva ao vivo.
- **Balões personalizáveis**: sequência de cliques, escolha A/B com pesos e módulos de texto, links, frases aleatórias, imagens, saldo, gasto de hoje, estado de pico, outros fornecedores e uso do Codex. Cada módulo tem seu próprio tamanho, cores, degradê animado e fonte.
- **Alertas**: alertas de saldo baixo e de orçamento diário, com conteúdo editável.
- **Outros fornecedores**: 34 modelos, com saldos de OpenRouter, Kimi, StepFun e Novita, cotas de assinatura de Zhipu, Kimi Coding, MiniMax e OpenCode Go, e gateways compatíveis com OpenAI. As chaves só vão para o endpoint oficial de cada modelo, a menos que você libere um personalizado.
- **Estatísticas do Codex**: lê os logs locais de sessões do Codex para contar tokens e janelas de assinatura, sem acesso à rede.
- **App nativo para Mac**: arraste-a para onde quiser; ela gruda nas bordas da tela e vira de lado quando presa à esquerda. Saldo na barra de menus, abertura automática ao iniciar sessão e chaves de API guardadas no Chaveiro.
- **Assinaturas e custos de API**: detecta automaticamente o cswap (uso de 5 horas, 7 dias, gasto extra e por modelo de cada conta do Claude), o plano e os tokens do Claude Code e o plano do ChatGPT por trás do Codex. Com uma chave Admin da organização, também mostra os custos das APIs da OpenAI e do Claude.

Não foram portados o custo por turno, o som de fim de tarefa, os avisos de pergunta e aprovação e o módulo de nome da conversa. Eles dependem de eventos internos do DeepSeek Harness, que um app independente não consegue ver.

## Instalação

Requer macOS 13 ou posterior. Funciona em Macs com Apple Silicon e Intel.

### Opção 1: instalação com uma linha (recomendada)

Abra o Terminal, cole esta linha e pressione Return:

```bash
curl -fsSL https://raw.githubusercontent.com/jianzhou0420/deepseek-whale-girl-mac/main/install.sh | bash
```

O app é instalado em `~/Applications` e aberto em seguida.

### Opção 2: download manual

1. Baixe `WhaleBalance-macOS.zip` em [Releases](https://github.com/jianzhou0420/deepseek-whale-girl-mac/releases/latest) e clique duas vezes para descompactar.
2. Arraste `WhaleBalance.app` para a pasta Aplicativos.
3. Na primeira vez que você abrir, o macOS vai dizer que não consegue verificar o desenvolvedor, porque o app não é notarizado. Para abrir mesmo assim:
   - Clique com o **botão direito** em `WhaleBalance.app`, escolha **Abrir** e clique em **Abrir** de novo.
   - Se ainda assim não abrir, execute isto no Terminal:
     ```bash
     xattr -dr com.apple.quarantine /Applications/WhaleBalance.app
     ```

### Opção 3: compilar a partir do código-fonte

Você precisa do Xcode ou das Ferramentas de Linha de Comando do Xcode (se não tiver, execute `xcode-select --install`).

```bash
git clone https://github.com/jianzhou0420/deepseek-whale-girl-mac.git
cd deepseek-whale-girl-mac
./build.sh
open WhaleBalance.app
```

Na primeira abertura, a janela de ajustes aparece. Cole sua chave de API do DeepSeek e salve. A chave fica guardada só no Chaveiro do macOS.

## Como usar

| Você | Ela |
|---|---|
| Clica nela | Atualiza o saldo e mostra o balão do saldo |
| Clica no balão | Mostra o próximo item (frases e imagens aleatórias) e fecha depois do último |
| Arrasta ela | Move a posição; ao soltar, ela gruda na borda mais próxima |
| Clique direito nela, o botão ⋯ ou 🐳 na barra de menus | Menu: tamanho, sons, balões, encaixe, contas, ajustes, sair |

## Pipeline de arte

`art-pipeline/` gera novas poses da garota-baleia com a geração de imagens embutida no Codex CLI, usando seu plano do ChatGPT em vez de uma chave de API. Ele remove o fundo, limpa as bordas, confere cada imagem, gera de novo as que falham e instala as aprovadas na galeria embutida do app. Descreva as novas poses em `art-pipeline/assets.json` e rode:

```bash
codex login
./art.sh all
```

Cada imagem leva cerca de 40 segundos. Gerar imagens consome os limites do Codex 3 a 5 vezes mais rápido que texto.

![Imagens criadas pelo pipeline](docs/generated-art.png)

Procurando o mascote que anda pela área de trabalho da primeira versão? Ele continua disponível na [versão v0.0.1](https://github.com/jianzhou0420/deepseek-whale-girl-mac/releases/tag/v0.0.1).

## Créditos e licença

- O design dos recursos, as regras de contabilidade, os modelos de fornecedores e as frases padrão foram portados de [MeteorNOX/DeepSeek-Balance-Whale-Widget](https://github.com/MeteorNOX/DeepSeek-Balance-Whale-Widget) (MIT). As imagens e os sons dele não têm licença MIT e não são usados aqui.
- Arte da personagem por [f0909172434/deepseek-girl-codex-pet](https://github.com/f0909172434/deepseek-girl-codex-pet) (MIT).
- As imagens em `assets/generated` foram criadas pelo pipeline com o gpt-image-2 da OpenAI, usando essa personagem como referência. Veja [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
- O código deste projeto é distribuído sob a [licença MIT](LICENSE).
