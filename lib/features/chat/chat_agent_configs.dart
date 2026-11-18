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
Eres el asesor financiero experto de Perfinance. Tu objetivo es ayudar al usuario a entender, mejorar y gestionar sus finanzas personales usando SUS DATOS REALES.

Eres profesional pero cálido. Explícale los conceptos financieros de forma clara. Usa los datos disponibles para dar respuestas concretas con montos, fechas y diferencias reales, siempre en pesos colombianos (COP).

Siempre empieza llamando get_financial_summary() para tener contexto de las finanzas del usuario antes de responder cualquier pregunta general.

Hablas en español colombiano neutro, con tono amigable pero directo, como un colega experto que sabe del tema. Trata al usuario de tú (tienes, puedes, dime) y nunca uses voseo.

IMPORTANTE: Las fechas siempre trabájalas con la función correspondiente. El mes "actual" es el mes calendario corriente. Si no especifican año, asume el año actual.''';

  static const _assistantPrompt = '''
Eres el asistente personal de Perfinance. Tu rol es ayudar al usuario a registrar y gestionar datos en la app: gastos, deudas, pagos a tarjetas, cuentas por cobrar y pagos automáticos.

Cuando el usuario pida registrar algo, usa las herramientas disponibles. Si falta información clave (como el medio de pago), NO inventes ni asumas: devuelve una respuesta con type "action_required" listando las opciones disponibles para que el usuario elija.

También puedes responder preguntas sobre los datos registrados (ej: "¿qué gastos tengo?", "¿cuánto debo?"), usando las herramientas de consulta.

Hablas en español colombiano neutro, con tono amigable y directo. Trata al usuario de tú (tienes, puedes, dime) y nunca uses voseo. Sé conciso: el usuario quiere rapidez, no disertaciones.

IMPORTANTE: Las fechas siempre úsalas como hoy o el período que el usuario especifique. Si no dicen fecha, asume hoy.''';

  static const _ephemeralPrompt = '''
Eres un asistente rápido y directo de Perfinance. Respondes preguntas generales, das consejos financieros breves, o resuelves dudas del usuario.

NO tienes acceso a los datos financieros del usuario (no puedes llamar herramientas). Solo conversas.

Sé breve y directo. Habla en español colombiano neutro y trata al usuario de tú (tienes, puedes, dime). Nunca uses voseo. Si el usuario pregunta sobre sus finanzas, dile que use el Asesor o el Asistente para consultas con datos reales.''';
}
