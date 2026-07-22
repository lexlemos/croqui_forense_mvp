import 'package:flutter/material.dart';
import 'package:croqui_forense_mvp/data/models/exames/detalhes_toxicologico_model.dart';

/// Widget de formulário isolado para a requisição de exames toxicológicos.
/// Cada material coletado expõe seu próprio campo de Nº Lacre para
/// rastreabilidade individual (cadeia de custódia — Lei 13.964/19).
class ToxicologicoFormWidget extends StatefulWidget {
  final DetalhesToxicologicoModel? initialData;
  final ValueChanged<DetalhesToxicologicoModel> onChanged;
  final bool readOnly;

  const ToxicologicoFormWidget({
    super.key,
    this.initialData,
    required this.onChanged,
    this.readOnly = false,
  });

  @override
  State<ToxicologicoFormWidget> createState() => _ToxicologicoFormWidgetState();
}

class _ToxicologicoFormWidgetState extends State<ToxicologicoFormWidget> {
  // Controladores criados imediatamente (não late) para evitar LateInitializationError.
  final TextEditingController _historicoOutroCtrl   = TextEditingController();
  final TextEditingController _materialSgOutroCtrl  = TextEditingController();
  final TextEditingController _lacreSgCtrl          = TextEditingController();
  final TextEditingController _lacreUrCtrl          = TextEditingController();
  final TextEditingController _lacreHvCtrl          = TextEditingController();
  final TextEditingController _lacreCeCtrl          = TextEditingController();
  final TextEditingController _lacrePmCtrl          = TextEditingController();

  String? _historicoOcorrencia;
  bool _materialSg         = false;
  bool _materialSgFemoral  = false;
  bool _materialSgCardiaca = false;
  bool _materialUrina      = false;
  bool _materialHumorVitreo= false;
  bool _materialEstomago   = false;
  bool _materialPulmao     = false;
  bool _quantificacaoDrogas= false;

  static const List<String> _opcoesHistorico = [
    'Ferimento por arma de fogo (FAF)',
    'Ferimento por arma branca (FAB)',
    'Acidente de trânsito',
    'Afogamento ou asfixia',
    'Morte suspeita',
    'Intoxicação exógena',
    'Outro',
  ];

  @override
  void initState() {
    super.initState();
    _initValues(widget.initialData);
  }

  @override
  void didUpdateWidget(covariant ToxicologicoFormWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialData != oldWidget.initialData) {
      setState(() => _initValues(widget.initialData));
    }
  }

  void _initValues(DetalhesToxicologicoModel? data) {
    _historicoOcorrencia = data?.historicoOcorrencia;
    String outroHist = data?.historicoOutro ?? '';
    if (_historicoOcorrencia != null &&
        !_opcoesHistorico.contains(_historicoOcorrencia)) {
      outroHist = _historicoOcorrencia!;
      _historicoOcorrencia = 'Outro';
    }
    _historicoOutroCtrl.text = outroHist;

    _materialSgFemoral  = data?.materialSgFemoral  ?? false;
    _materialSgCardiaca = data?.materialSgCardiaca ?? false;
    _materialSgOutroCtrl.text = data?.materialSgOutro ?? '';
    _materialSg = data != null
        ? (data.materialSgFemoral ||
            data.materialSgCardiaca ||
            (data.materialSgOutro?.isNotEmpty == true))
        : false;

    _lacreSgCtrl.text = data?.numeroLacreSg ?? '';
    _materialUrina       = data?.materialUrina       ?? false;
    _lacreUrCtrl.text    = data?.numeroLacreUr       ?? '';
    _materialHumorVitreo = data?.materialHumorVitreo ?? false;
    _lacreHvCtrl.text    = data?.numeroLacreHv       ?? '';
    _materialEstomago    = data?.materialEstomago    ?? false;
    _lacreCeCtrl.text    = data?.numeroLacreCe       ?? '';
    _materialPulmao      = data?.materialPulmao      ?? false;
    _lacrePmCtrl.text    = data?.numeroLacrePm       ?? '';
    _quantificacaoDrogas = data?.quantificacaoDrogas ?? false;
  }

  @override
  void dispose() {
    _historicoOutroCtrl.dispose();
    _materialSgOutroCtrl.dispose();
    _lacreSgCtrl.dispose();
    _lacreUrCtrl.dispose();
    _lacreHvCtrl.dispose();
    _lacreCeCtrl.dispose();
    _lacrePmCtrl.dispose();
    super.dispose();
  }

  void _notifyChanges() {
    final model = DetalhesToxicologicoModel(
      uuid: widget.initialData?.uuid ?? '',
      exameUuid: widget.initialData?.exameUuid ?? '',
      historicoOcorrencia: _historicoOcorrencia,
      historicoOutro:
          _historicoOcorrencia == 'Outro' ? _historicoOutroCtrl.text.trim() : null,
      materialSgFemoral: _materialSg ? _materialSgFemoral : false,
      materialSgCardiaca: _materialSg ? _materialSgCardiaca : false,
      materialSgOutro: _materialSg && _materialSgOutroCtrl.text.trim().isNotEmpty
          ? _materialSgOutroCtrl.text.trim()
          : null,
      numeroLacreSg: _materialSg && _lacreSgCtrl.text.trim().isNotEmpty
          ? _lacreSgCtrl.text.trim()
          : null,
      materialUrina: _materialUrina,
      numeroLacreUr: _materialUrina && _lacreUrCtrl.text.trim().isNotEmpty
          ? _lacreUrCtrl.text.trim()
          : null,
      materialHumorVitreo: _materialHumorVitreo,
      numeroLacreHv: _materialHumorVitreo && _lacreHvCtrl.text.trim().isNotEmpty
          ? _lacreHvCtrl.text.trim()
          : null,
      materialEstomago: _materialEstomago,
      numeroLacreCe: _materialEstomago && _lacreCeCtrl.text.trim().isNotEmpty
          ? _lacreCeCtrl.text.trim()
          : null,
      materialPulmao: _materialPulmao,
      numeroLacrePm: _materialPulmao && _lacrePmCtrl.text.trim().isNotEmpty
          ? _lacrePmCtrl.text.trim()
          : null,
      quantificacaoDrogas: _quantificacaoDrogas,
    );
    widget.onChanged(model);
  }

  /// Campo de lacre compacto reutilizável.
  Widget _lacreField({
    required TextEditingController ctrl,
    required String label,
  }) {
    return Padding(
      padding: const EdgeInsets.only(left: 28, right: 0, top: 4, bottom: 8),
      child: TextFormField(
        controller: ctrl,
        enabled: !widget.readOnly,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: 'Nº Lacre — $label *',
          hintText: 'Ex: 123456',
          prefixIcon: Icon(Icons.lock_outline, color: Colors.purple.shade600, size: 18),
          border: const OutlineInputBorder(),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          helperText: 'Identifica individualmente este recipiente lacrado',
          helperStyle: TextStyle(fontSize: 10, color: Colors.grey.shade600),
        ),
        onChanged: (_) => _notifyChanges(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0.5,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.purple.shade100),
      ),
      color: Colors.purple.shade50.withValues(alpha: 0.3),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabeçalho
            Row(
              children: [
                Icon(Icons.biotech, color: Colors.purple.shade700, size: 22),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Detalhes do Exame Toxicológico',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.purple.shade900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 1. Histórico da Ocorrência
            DropdownButtonFormField<String>(
              value: _opcoesHistorico.contains(_historicoOcorrencia)
                  ? _historicoOcorrencia
                  : null,
              decoration: const InputDecoration(
                labelText: 'Histórico da Ocorrência',
                prefixIcon: Icon(Icons.history_edu, size: 20),
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
              ),
              items: _opcoesHistorico.map((opt) {
                return DropdownMenuItem<String>(
                  value: opt,
                  child: Text(opt, style: const TextStyle(fontSize: 14)),
                );
              }).toList(),
              onChanged: widget.readOnly
                  ? null
                  : (val) {
                      setState(() => _historicoOcorrencia = val);
                      _notifyChanges();
                    },
            ),

            if (_historicoOcorrencia == 'Outro') ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _historicoOutroCtrl,
                enabled: !widget.readOnly,
                decoration: const InputDecoration(
                  labelText: 'Descreva o histórico (Outro)',
                  prefixIcon: Icon(Icons.edit_note, size: 20),
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.white,
                ),
                onChanged: (_) => _notifyChanges(),
              ),
            ],

            const SizedBox(height: 20),
            Text(
              'Material Coletado',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.blueGrey.shade800,
              ),
            ),
            const SizedBox(height: 8),

            // ── SG Sangue ─────────────────────────────────────────────────
            CheckboxListTile(
              title: const Text(
                'SG Sangue (tubo vacutainer)',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              value: _materialSg,
              enabled: !widget.readOnly,
              dense: true,
              activeColor: Colors.purple.shade700,
              controlAffinity: ListTileControlAffinity.leading,
              onChanged: widget.readOnly
                  ? null
                  : (val) {
                      setState(() {
                        _materialSg = val ?? false;
                        if (!_materialSg) {
                          _materialSgFemoral = false;
                          _materialSgCardiaca = false;
                          _materialSgOutroCtrl.clear();
                          _lacreSgCtrl.clear();
                          _quantificacaoDrogas = false;
                        } else {
                          _materialSgFemoral = true;
                        }
                      });
                      _notifyChanges();
                    },
            ),

            if (_materialSg) ...[
              Padding(
                padding: const EdgeInsets.only(left: 28.0, top: 4, bottom: 4),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.purple.shade100),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CheckboxListTile(
                        title: const Text('Veia femoral',
                            style: TextStyle(fontSize: 13)),
                        value: _materialSgFemoral,
                        enabled: !widget.readOnly,
                        dense: true,
                        activeColor: Colors.purple.shade700,
                        controlAffinity: ListTileControlAffinity.leading,
                        onChanged: widget.readOnly
                            ? null
                            : (val) {
                                setState(() => _materialSgFemoral = val ?? false);
                                _notifyChanges();
                              },
                      ),
                      CheckboxListTile(
                        title: const Text('Cavidade cardíaca',
                            style: TextStyle(fontSize: 13)),
                        value: _materialSgCardiaca,
                        enabled: !widget.readOnly,
                        dense: true,
                        activeColor: Colors.purple.shade700,
                        controlAffinity: ListTileControlAffinity.leading,
                        onChanged: widget.readOnly
                            ? null
                            : (val) {
                                setState(() => _materialSgCardiaca = val ?? false);
                                _notifyChanges();
                              },
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _materialSgOutroCtrl,
                        enabled: !widget.readOnly,
                        decoration: const InputDecoration(
                          labelText: 'Outro sítio de coleta de sangue',
                          border: OutlineInputBorder(),
                          isDense: true,
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        onChanged: (_) => _notifyChanges(),
                      ),
                      const SizedBox(height: 12),
                      const Divider(),
                      SwitchListTile(
                        title: const Text(
                          'Quantificação de drogas / fármacos?',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        subtitle: const Text(
                          'Solicitar análise quantitativa em sangue',
                          style: TextStyle(fontSize: 11),
                        ),
                        value: _quantificacaoDrogas,
                        activeColor: Colors.purple.shade700,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        onChanged: widget.readOnly
                            ? null
                            : (val) {
                                setState(() => _quantificacaoDrogas = val);
                                _notifyChanges();
                              },
                      ),
                    ],
                  ),
                ),
              ),
              // Lacre individual do tubo de sangue
              _lacreField(ctrl: _lacreSgCtrl, label: 'Sangue (SG)'),
            ],

            // ── UR Urina ──────────────────────────────────────────────────
            CheckboxListTile(
              title: const Text('UR Urina (coletor universal)',
                  style: TextStyle(fontSize: 14)),
              value: _materialUrina,
              enabled: !widget.readOnly,
              dense: true,
              activeColor: Colors.purple.shade700,
              controlAffinity: ListTileControlAffinity.leading,
              onChanged: widget.readOnly
                  ? null
                  : (val) {
                      setState(() {
                        _materialUrina = val ?? false;
                        if (!_materialUrina) _lacreUrCtrl.clear();
                      });
                      _notifyChanges();
                    },
            ),
            if (_materialUrina)
              _lacreField(ctrl: _lacreUrCtrl, label: 'Urina (UR)'),

            // ── HV Humor Vítreo ───────────────────────────────────────────
            CheckboxListTile(
              title: const Text('HV Humor vítreo (tubo vacutainer)',
                  style: TextStyle(fontSize: 14)),
              value: _materialHumorVitreo,
              enabled: !widget.readOnly,
              dense: true,
              activeColor: Colors.purple.shade700,
              controlAffinity: ListTileControlAffinity.leading,
              onChanged: widget.readOnly
                  ? null
                  : (val) {
                      setState(() {
                        _materialHumorVitreo = val ?? false;
                        if (!_materialHumorVitreo) _lacreHvCtrl.clear();
                      });
                      _notifyChanges();
                    },
            ),
            if (_materialHumorVitreo)
              _lacreField(ctrl: _lacreHvCtrl, label: 'Humor Vítreo (HV)'),

            // ── CE Estômago ───────────────────────────────────────────────
            CheckboxListTile(
              title: const Text('CE Estômago (conteúdo estomacal)',
                  style: TextStyle(fontSize: 14)),
              value: _materialEstomago,
              enabled: !widget.readOnly,
              dense: true,
              activeColor: Colors.purple.shade700,
              controlAffinity: ListTileControlAffinity.leading,
              onChanged: widget.readOnly
                  ? null
                  : (val) {
                      setState(() {
                        _materialEstomago = val ?? false;
                        if (!_materialEstomago) _lacreCeCtrl.clear();
                      });
                      _notifyChanges();
                    },
            ),
            if (_materialEstomago)
              _lacreField(ctrl: _lacreCeCtrl, label: 'Conteúdo Estomacal (CE)'),

            // ── PM Pulmão ─────────────────────────────────────────────────
            CheckboxListTile(
              title: const Text('PM Pulmão (fragmentos)',
                  style: TextStyle(fontSize: 14)),
              value: _materialPulmao,
              enabled: !widget.readOnly,
              dense: true,
              activeColor: Colors.purple.shade700,
              controlAffinity: ListTileControlAffinity.leading,
              onChanged: widget.readOnly
                  ? null
                  : (val) {
                      setState(() {
                        _materialPulmao = val ?? false;
                        if (!_materialPulmao) _lacrePmCtrl.clear();
                      });
                      _notifyChanges();
                    },
            ),
            if (_materialPulmao)
              _lacreField(ctrl: _lacrePmCtrl, label: 'Pulmão (PM)'),
          ],
        ),
      ),
    );
  }
}