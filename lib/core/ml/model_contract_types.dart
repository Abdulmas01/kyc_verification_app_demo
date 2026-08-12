enum ModelTensorLayout { nchw, nhwc }

class ModelNormalization {
  const ModelNormalization({
    required this.scale,
    required this.mean,
    required this.std,
  });

  final double scale;
  final List<double> mean;
  final List<double> std;
}
