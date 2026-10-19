class MeshRemnant {
  final String id;
  final double widthCm;
  final double lengthCm;
  final bool isConsumed;

  const MeshRemnant({
    required this.id,
    required this.widthCm,
    required this.lengthCm,
    this.isConsumed = false,
  });

  double get areaCm2 => widthCm * lengthCm;

  /// Strict physical check: both width AND length must fit (orientation non-rotating or rotating if allowed)
  bool canFulfill({
    required double reqWidthCm,
    required double reqLengthCm,
    bool allowRotation = true,
  }) {
    if (isConsumed) return false;

    // Normal orientation check
    final fitsNormal = reqWidthCm <= widthCm && reqLengthCm <= lengthCm;
    if (fitsNormal) return true;

    if (allowRotation) {
      // Rotated orientation check (width along length, length along width)
      final fitsRotated = reqWidthCm <= lengthCm && reqLengthCm <= widthCm;
      if (fitsRotated) return true;
    }

    return false;
  }
}

class MeshCutDecision {
  final bool isApproved;
  final String? remnantId;
  final String? rejectionReason;
  final double remainingWidthCm;
  final double remainingLengthCm;

  const MeshCutDecision({
    required this.isApproved,
    this.remnantId,
    this.rejectionReason,
    this.remainingWidthCm = 0.0,
    this.remainingLengthCm = 0.0,
  });
}

class MeshOptimizer {
  const MeshOptimizer();

  /// Evaluates whether a requested mesh piece can be cut from a roll or remnant
  static MeshCutDecision evaluateCut({
    required double requestedWidthCm,
    required double requestedLengthCm,
    required MeshRemnant source,
    bool allowRotation = true,
  }) {
    if (source.isConsumed) {
      return const MeshCutDecision(
        isApproved: false,
        rejectionReason: 'Cannot consume remnant: already marked as consumed.',
      );
    }

    final fits = source.canFulfill(
      reqWidthCm: requestedWidthCm,
      reqLengthCm: requestedLengthCm,
      allowRotation: allowRotation,
    );

    if (!fits) {
      return MeshCutDecision(
        isApproved: false,
        rejectionReason:
            'Insufficient dimensions: Requested ${requestedWidthCm}x$requestedLengthCm cm cannot be cut from available ${source.widthCm}x${source.lengthCm} cm (Never cut by area alone).',
      );
    }

    // Calculate leftover remnant dimensions assuming linear cut along width
    final remainingW = source.widthCm - requestedWidthCm;
    final remainingL = source.lengthCm - requestedLengthCm;

    return MeshCutDecision(
      isApproved: true,
      remnantId: source.id,
      remainingWidthCm: remainingW >= 0 ? remainingW : 0,
      remainingLengthCm: remainingL >= 0 ? remainingL : 0,
    );
  }
}
