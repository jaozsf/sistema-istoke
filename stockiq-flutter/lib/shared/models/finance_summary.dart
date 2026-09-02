class FinanceSummary {
  final double receita;
  final double custo;
  final double lucro;

  const FinanceSummary({required this.receita, required this.custo, required this.lucro});

  factory FinanceSummary.fromJson(Map<String, dynamic> json) => FinanceSummary(
        receita: (json['receita'] as num).toDouble(),
        custo: (json['custo'] as num).toDouble(),
        lucro: (json['lucro'] as num).toDouble(),
      );
}
