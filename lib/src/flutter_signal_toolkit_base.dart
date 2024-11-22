import 'dart:math' as math;
import 'dart:io';

class SignalToolkit {
  /// Generates bandpass filtered Gaussian white noise
  /// 
  /// Parameters:
  /// - [length]: Number of samples to generate (default: 1000).
  /// - [samplingFreq]: Sampling frequency in Hz (default: 44100.0).
  /// - [lowCutoff]: Lower cutoff frequency in Hz (default: 20.0).
  /// - [highCutoff]: Higher cutoff frequency in Hz (default: 2000.0).
  /// - [order]: Order of the filter (default: 2).
  /// 
  /// Returns a `List<int>` with values between 0 and 255.
  static List<int> generateNoise({
    int length = 1000,
    double samplingFreq = 44100.0,
    double lowCutoff = 20.0,
    double highCutoff = 2000.0,
    int order = 2,
  }) {
    // Validate parameters
    if (highCutoff > samplingFreq / 2) {
      throw ArgumentError(
          'High cutoff frequency must be less than half the sampling frequency.');
    }
    if (lowCutoff >= highCutoff) {
      throw ArgumentError('Low cutoff must be less than high cutoff frequency.');
    }

    final random = math.Random();

    // Generate Gaussian white noise using the Box-Muller transform
    final List<double> noise = List.generate(length + 500, (_) {
      final u1 = random.nextDouble();
      final u2 = random.nextDouble();
      return math.sqrt(-2 * math.log(u1)) * math.cos(2 * math.pi * u2);
    });

    // Normalize and scale raw noise to 0-255 range
    final List<int> scaledNoise = _normalizeAndScale(noise);

    // Apply bandpass filter
    final List<double> filteredNoise = _bandpassFilter(
      signal: noise,
      samplingFreq: samplingFreq,
      lowCutoff: lowCutoff,
      highCutoff: highCutoff,
      order: order,
    );

    // Remove initial transient and scale the filtered noise
    final List<double> trimmedNoise = filteredNoise.sublist(500);
    return _normalizeAndScale(trimmedNoise);
  }

  /// Applies an IIR bandpass filter to the input signal
  /// 
  /// Parameters:
  /// - [signal]: The input signal as a `List<double>`.
  /// - [samplingFreq]: Sampling frequency in Hz.
  /// - [lowCutoff]: Lower cutoff frequency in Hz.
  /// - [highCutoff]: Higher cutoff frequency in Hz.
  /// - [order]: Order of the filter (default: 1).
  static List<double> _bandpassFilter({
    required List<double> signal,
    required double samplingFreq,
    required double lowCutoff,
    required double highCutoff,
    int order = 1,
  }) {
    final double w1 = 2 * math.pi * lowCutoff / samplingFreq;
    final double w2 = 2 * math.pi * highCutoff / samplingFreq;

    final double wc = (w1 + w2) / 2;
    final double bw = w2 - w1;
    final double q = wc / bw;

    final double alpha = math.sin(wc) * math.sin(math.log(2) / 2 * bw * wc / math.sin(wc));
    final double cosw0 = math.cos(wc);

    double b0 = alpha;
    double b1 = 0;
    double b2 = -alpha;
    double a0 = 1 + alpha;
    double a1 = -2 * cosw0;
    double a2 = 1 - alpha;

    b0 /= a0;
    b1 /= a0;
    b2 /= a0;
    a1 /= a0;
    a2 /= a0;

    List<double> filtered = List.from(signal);

    for (int n = 0; n < order; n++) {
      final List<double> x = List.from(filtered);
      final List<double> y = List.filled(signal.length, 0);

      y[0] = b0 * x[0];
      if (signal.length > 1) {
        y[1] = b0 * x[1] + b1 * x[0] - a1 * y[0];
      }

      for (int i = 2; i < signal.length; i++) {
        y[i] = b0 * x[i] +
            b1 * x[i - 1] +
            b2 * x[i - 2] -
            a1 * y[i - 1] -
            a2 * y[i - 2];
      }

      filtered = y;
    }

    return filtered;
  }

  /// Normalizes and scales a signal to the 0-255 range
  static List<int> _normalizeAndScale(List<double> signal) {
    final double mean = signal.reduce((a, b) => a + b) / signal.length;
    final double variance = signal
            .map((x) => math.pow(x - mean, 2))
            .reduce((a, b) => a + b) /
        signal.length;
    final double stdDev = math.sqrt(variance);

    return signal.map((sample) {
      final int scaled = ((sample - mean) / (3 * stdDev) * 127.5 + 127.5).round();
      return scaled.clamp(0, 255);
    }).toList();
  }

  /// Saves the data to a text file
  /// 
  /// Parameters:
  /// - [data]: List of integers to save.
  /// - [filename]: Name of the file (without extension).
  /// 
  /// Returns the full path of the saved file.
  static Future<String> saveToFile({
    required List<int> data,
    required String filename,
  }) async {
    try {
      final String fullPath = '/Users/boramert/Desktop/Noise/$filename.txt';
      final File file = File(fullPath);

      await file.writeAsString(data.join('\n'));
      return fullPath;
    } catch (e) {
      throw Exception('Failed to save data: $e');
    }
  }
}