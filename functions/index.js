const functions = require("firebase-functions");
const {MercadoPagoConfig, Preference} = require("mercadopago");

/**
 * Crea una preferencia de pago en Mercado Pago.
 * Recibe los detalles del item y devuelve una URL de checkout (init_point).
 * @param {functions.https.Request} req El objeto de solicitud de Express.
 * @param {functions.Response} res El objeto de respuesta de Express.
 */
exports.createPreference = functions.https.onRequest(async (req, res) => {
  res.set("Access-Control-Allow-Origin", "*");

  // Volvemos a leer la variable de entorno directamente.
  const accessToken = process.env.MERCADOPAGO_TOKEN;

  if (!accessToken) {
    const errorMsg = "El Access Token de Mercado Pago (MERCADOPAGO_TOKEN) " +
                   "no está configurado en las variables de entorno.";
    functions.logger.error(errorMsg, {structuredData: true});
    return res.status(500).json({
      error: "Error de configuración del servidor.",
    });
  }

  if (req.method !== "POST") {
    return res.status(405).send("Method Not Allowed");
  }

  try {
    const {title, description, quantity, unitPrice} = req.body;
    if (!title || !quantity || !unitPrice) {
      throw new Error("Faltan parámetros requeridos.");
    }

    const preferenceData = {
      items: [
        {
          title: title,
          description: description,
          quantity: Number(quantity),
          currency_id: "ARS",
          unit_price: Number(unitPrice),
        },
      ],
      back_urls: {
        // Usamos un Deep Link para que Mercado Pago nos devuelva a la app.
        success: "reservasapp://payment/success",
        failure: "reservasapp://payment/failure",
        pending: "reservasapp://payment/pending",
      },
    };

    // --- DEPURACIÓN FINAL ---
    // Registramos el objeto completo que se enviará a Mercado Pago.
    functions.logger.info(
        "Enviando preferencia a Mercado Pago:", preferenceData);

    // 2. Crear el cliente y la preferencia con la nueva sintaxis
    const client = new MercadoPagoConfig({accessToken: accessToken});
    const preference = new Preference(client);

    const result = await preference.create({body: preferenceData});
    functions.logger.info("Preferencia creada:", {id: result.id});

    // Para pagos reales, solo devolvemos el init_point y el ID de la preferencia.
    const responseBody = {init_point: result.init_point, id: result.id};

    return res.status(200).json(responseBody);
  } catch (error) {
    functions.logger.error("Error al crear la preferencia:", error);
    const code = error.message === "Faltan parámetros requeridos." ? 400 : 500;
    return res.status(code).send(error.message);
  }
});
