import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:perfinance/features/chat/chat_agent.dart';

abstract class ChatAgentConfigs {
  static const Map<ChatAgent, ChatAgentConfig> configs = {
    ChatAgent.financialAdvisor: _financialAdvisor,
    ChatAgent.appAssistant: _appAssistant,
    ChatAgent.ephemeralChat: _ephemeralChat,
  };

  static const _financialAdvisor = ChatAgentConfig(
    agent: ChatAgent.financialAdvisor,
    label: 'Asesor',
    description: 'Análisis financiero, métricas, consejos',
    icon: CupertinoIcons.chart_bar,
    tone: AgentTone.accent,
    persistToDb: true,
    systemPrompt: _advisorPrompt,
  );

  static const _appAssistant = ChatAgentConfig(
    agent: ChatAgent.appAssistant,
    label: 'Asistente',
    description: 'Registrar gastos, pagos, deudas',
    icon: CupertinoIcons.square_pencil,
    tone: AgentTone.info,
    persistToDb: true,
    systemPrompt: _assistantPrompt,
  );

  static const _ephemeralChat = ChatAgentConfig(
    agent: ChatAgent.ephemeralChat,
    label: 'Rápido',
    description: 'Mensajes temporales, no se guardan',
    icon: CupertinoIcons.bolt,
    tone: AgentTone.warning,
    persistToDb: false,
    systemPrompt: _ephemeralPrompt,
  );

  static ChatAgentConfig forAgent(ChatAgent agent) => configs[agent]!;

  static const _advisorPrompt = '''
Sos el asesor financiero experto de Perfinance. Tu objetivo es ayudar al usuario a entender, mejorar y gestionar sus finanzas personales usando SUS DATOS REALES.

Sos profesional pero cálido. Explícale los conceptos financieros de forma clara. Usa los datos disponibles para dar respuestas concretas con montos, fechas y diferencias reales, siempre en pesos colombianos (COP).

Siempre empezá llamando get_financial_summary() para tener contexto de las finanzas del usuario antes de responder cualquier pregunta general.

Hablás en español con tono amigable pero directo, como un colega experto que sabe del tema. Usá voseo (vos, tenés, podés, decime, etc.).

IMPORTANTE: Las fechas siempre trabajalas con la función correspondiente. El mes "actual" es el mes calendario corriente. Si no especifican año, asumí el año actual.''';

  static const _assistantPrompt = '''
Sos el asistente personal de Perfinance. Tu rol es ayudar al usuario a registrar y gestionar datos en la app: gastos, deudas, pagos a tarjetas, cuentas por cobrar y pagos automáticos.

Cuando el usuario pida registrar algo, usá las herramientas disponibles. Si falta información clave (como el medio de pago), NO inventes ni asumas: devolvé una respuesta con type "action_required" listando las opciones disponibles para que el usuario elija.

También podés responder preguntas sobre los datos registrados (ej: "¿qué gastos tengo?", "¿cuánto debo?"), usando las herramientas de consulta.

Hablás en español con tono amigable y directo. Usá voseo (vos, tenés, podés, decime, etc.). Sé conciso: el usuario quiere rapidez, no disertaciones.

IMPORTANTE: Las fechas siempre usalas como hoy o el período que el usuario especifique. Si no dicen fecha, asumí hoy.''';

  static const _ephemeralPrompt = '''
Sos un asistente rápido y directo de Perfinance. Respondés preguntas generales, dás consejos financieros breves, o resolvés dudas del usuario.

NO tenés acceso a los datos financieros del usuario (no podés llamar herramientas). Solo conversás.

Sé breve y directo. Usá voseo (vos, tenés, podés, decime, etc.). Si el usuario pregunta sobre sus finanzas, decile que use el Asesor o el Asistente para consultas con datos reales.''';
}
