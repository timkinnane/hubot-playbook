var Handlebars, HandlebarsIntl, context, intlData, string, template, rendered;

icu = require('full-icu');
console.log(icu);
console.log('ICU loaded: '+icu.haveDat());

Handlebars = require('handlebars');
HandlebarsIntl = require('handlebars-intl');
HandlebarsIntl.registerWith(Handlebars);

string = '{{formatDate date day="numeric" month="long" year="numeric"}}';
intlData = { locales: "fr-FR" };
context = { date: new Date() };

template = Handlebars.compile(string);
rendered = template(context, { data: {intl: intlData} });

console.log(rendered);
