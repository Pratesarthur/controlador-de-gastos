import 'package:flutter/material.dart';

enum Kind { expense, income }

/// Supplies the user's goals as subcategories of the "Metas" categories (set by the Store).
List<Sub> Function() goalSubsProvider = () => const [];

class Sub {
  final String id, name;
  const Sub(this.id, this.name);
}

class Category {
  final String id, name;
  final IconData icon;
  final Color color;
  final Kind kind;
  final List<Sub> _subs;
  final bool dynamicSubs; // subcategories are the user's goals
  const Category(this.id, this.name, this.icon, this.color, this.kind, [this._subs = const [], this.dynamicSubs = false]);

  List<Sub> get subs => dynamicSubs ? goalSubsProvider() : _subs;

  Sub? subById(String? id) {
    if (id == null) return null;
    for (final s in subs) {
      if (s.id == id) return s;
    }
    return null;
  }
}

const categories = <Category>[
  Category(
    'alimentacao',
    'Alimentação',
    Icons.restaurant_outlined,
    Color(0xFF374151),
    Kind.expense,
    [
      Sub('mercado', 'Mercado'),
      Sub('delivery', 'Delivery'),
      Sub('restaurantes', 'Restaurantes'),
      Sub('ocasioes', 'Outras Ocasiões'),
    ],
  ),
  Category(
    'moradia',
    'Moradia',
    Icons.home_outlined,
    Color(0xFFFF4D0D),
    Kind.expense,
    [
      Sub('aluguel', 'Aluguel e financiamento'),
      Sub('condominio', 'Condomínio'),
      Sub('contas', 'Luz, água e gás'),
      Sub('internet', 'Internet e telefone'),
      Sub('manutencao', 'Manutenção e reparos'),
    ],
  ),
  Category(
    'transporte',
    'Transporte',
    Icons.directions_car_outlined,
    Color(0xFF8FB0E8),
    Kind.expense,
    [
      Sub('combustivel', 'Combustível'),
      Sub('apps', 'Aplicativos de transporte'),
      Sub('publico', 'Transporte público'),
      Sub('veiculo', 'Seguro e manutenção'),
      Sub('estacionamento', 'Estacionamento e pedágio'),
    ],
  ),
  Category(
    'lazer',
    'Lazer',
    Icons.sports_esports_outlined,
    Color(0xFFB4B4B8),
    Kind.expense,
    [
      Sub('cinema', 'Cinema, shows e eventos'),
      Sub('jogos', 'Jogos'),
      Sub('hobbies', 'Hobbies'),
      Sub('bares', 'Bares e festas'),
    ],
  ),
  Category(
    'viagem',
    'Viagem',
    Icons.flight_takeoff_rounded,
    Color(0xFF5EB8AE),
    Kind.expense,
    [
      Sub('passagens', 'Passagens'),
      Sub('hospedagem', 'Hospedagem'),
      Sub('passeios', 'Passeios'),
    ],
  ),
  Category(
    'saude',
    'Saúde',
    Icons.favorite_border_rounded,
    Color(0xFF16A34A),
    Kind.expense,
    [
      Sub('farmacia', 'Farmácia'),
      Sub('consultas', 'Consultas e exames'),
      Sub('plano', 'Plano de saúde'),
      Sub('academia', 'Academia e esportes'),
    ],
  ),
  Category(
    'educacao',
    'Educação',
    Icons.school_outlined,
    Color(0xFF7C5CFF),
    Kind.expense,
    [
      Sub('mensalidade', 'Mensalidade'),
      Sub('cursos', 'Cursos'),
      Sub('livros', 'Livros e materiais'),
    ],
  ),
  Category(
    'compras',
    'Compras',
    Icons.shopping_bag_outlined,
    Color(0xFFE5489B),
    Kind.expense,
    [
      Sub('roupas', 'Roupas e calçados'),
      Sub('eletronicos', 'Eletrônicos'),
      Sub('casa', 'Casa e decoração'),
      Sub('presentes', 'Presentes'),
    ],
  ),
  Category(
    'assinaturas',
    'Assinaturas',
    Icons.subscriptions_outlined,
    Color(0xFF0EA5A5),
    Kind.expense,
    [
      Sub('streaming', 'Streaming'),
      Sub('software', 'Apps e software'),
      Sub('clubes', 'Clubes e associações'),
    ],
  ),
  Category(
    'cuidados',
    'Cuidados pessoais',
    Icons.spa_outlined,
    Color(0xFFD9A37A),
    Kind.expense,
    [
      Sub('beleza', 'Salão e barbearia'),
      Sub('higiene', 'Higiene e cosméticos'),
    ],
  ),
  Category(
    'pets',
    'Pets',
    Icons.pets_outlined,
    Color(0xFF8B5E3C),
    Kind.expense,
    [
      Sub('racao', 'Ração e petiscos'),
      Sub('veterinario', 'Veterinário'),
      Sub('petshop', 'Banho e pet shop'),
    ],
  ),
  Category(
    'familia',
    'Família e filhos',
    Icons.child_care_outlined,
    Color(0xFFF2A93B),
    Kind.expense,
    [
      Sub('escola', 'Escola e creche'),
      Sub('brinquedos', 'Brinquedos e roupas'),
      Sub('mesada', 'Mesada'),
    ],
  ),
  Category(
    'servicos',
    'Serviços e taxas',
    Icons.account_balance_outlined,
    Color(0xFF3B2A8F),
    Kind.expense,
    [
      Sub('tarifas', 'Tarifas bancárias'),
      Sub('impostos', 'Impostos'),
      Sub('seguros', 'Seguros'),
      Sub('juros', 'Juros e multas'),
    ],
  ),
  Category('metas', 'Metas (guardar)', Icons.flag_rounded, Color(0xFF2F6BFF), Kind.expense, [], true),
  Category(
    'outros',
    'Outros',
    Icons.more_horiz_rounded,
    Color(0xFF6B7280),
    Kind.expense,
    [
      Sub('doacoes', 'Doações'),
      Sub('imprevistos', 'Imprevistos'),
      Sub('diversos', 'Diversos'),
    ],
  ),
  Category('metas_ret', 'Metas (retirar)', Icons.flag_outlined, Color(0xFF2F6BFF), Kind.income, [], true),
  Category(
    'salario',
    'Salário',
    Icons.payments_outlined,
    Color(0xFF16A34A),
    Kind.income,
    [
      Sub('mensal', 'Salário mensal'),
      Sub('13', '13º salário'),
      Sub('ferias', 'Férias'),
      Sub('bonus', 'Bônus e comissões'),
    ],
  ),
  Category(
    'freela',
    'Freelance',
    Icons.laptop_mac_rounded,
    Color(0xFF0EA5A5),
    Kind.income,
    [Sub('projetos', 'Projetos'), Sub('consultoria', 'Consultoria')],
  ),
  Category(
    'invest',
    'Investimentos',
    Icons.trending_up_rounded,
    Color(0xFF3B82F6),
    Kind.income,
    [
      Sub('dividendos', 'Dividendos'),
      Sub('rendimentos', 'Rendimentos'),
      Sub('resgates', 'Resgates'),
    ],
  ),
  Category(
    'vendas',
    'Vendas',
    Icons.sell_outlined,
    Color(0xFFF2A93B),
    Kind.income,
    [Sub('usados', 'Itens usados'), Sub('negocio', 'Negócio próprio')],
  ),
  Category(
    'outras_rec',
    'Outras receitas',
    Icons.add_card_outlined,
    Color(0xFF8B5E3C),
    Kind.income,
    [
      Sub('reembolsos', 'Reembolsos'),
      Sub('presentes_rec', 'Presentes'),
      Sub('alugueis', 'Aluguéis recebidos'),
    ],
  ),
];

Category categoryById(String id) => categories.firstWhere(
  (c) => c.id == id,
  orElse: () => categories.firstWhere((c) => c.id == 'outros'),
);
