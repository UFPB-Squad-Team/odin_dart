enum TerritoryLayer {
  municipio('Municípios'),
  bairro('Bairros');

  const TerritoryLayer(this.label);

  final String label;
}
