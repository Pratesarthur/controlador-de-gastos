import 'package:cloud_firestore/cloud_firestore.dart';

import 'store.dart';

/// How the app's objects become Firestore documents (and back).
///
/// Firestore layout — every user only ever touches their own branch:
///
///   users/{uid}                    name, email, photo, favourite account/card
///   users/{uid}/transactions/{id}  one document per entry (each installment is its own entry)
///   users/{uid}/accounts/{id}
///   users/{uid}/cards/{id}
///   users/{uid}/goals/{id}
///
/// Accounts, cards and goals carry an `order` field so they come back in creation order.

typedef Json = Map<String, dynamic>;

Json txnToMap(Txn t) => {
  'title': t.title,
  'categoryId': t.categoryId,
  'subId': t.subId,
  'amount': t.amount,
  'kind': t.kind.name,
  'date': Timestamp.fromDate(t.date),
  'accountId': t.accountId,
  'isCard': t.isCard,
  'inst': t.inst,
  'instTotal': t.instTotal,
  'recurring': t.recurring,
  'group': t.group,
};

Txn txnFromDoc(DocumentSnapshot<Json> d) {
  final m = d.data()!;
  return Txn(
    int.parse(d.id),
    m['title'] as String,
    m['categoryId'] as String,
    (m['amount'] as num).toDouble(),
    Kind.values.byName(m['kind'] as String),
    (m['date'] as Timestamp).toDate(),
    accountId: m['accountId'] as String,
    isCard: m['isCard'] as bool? ?? false,
    inst: (m['inst'] as num?)?.toInt() ?? 1,
    instTotal: (m['instTotal'] as num?)?.toInt() ?? 1,
    subId: m['subId'] as String?,
    recurring: m['recurring'] as bool? ?? false,
    group: (m['group'] as num?)?.toInt(),
  );
}

Json accountToMap(Account a, int order) => {'name': a.name, 'initial': a.initial, 'order': order};

Account accountFromDoc(DocumentSnapshot<Json> d) {
  final m = d.data()!;
  return Account(d.id, m['name'] as String, (m['initial'] as num).toDouble());
}

Json cardToMap(CardAcct c, int order) => {
  'name': c.name,
  'closingDay': c.closingDay,
  'limit': c.limit,
  'order': order,
};

CardAcct cardFromDoc(DocumentSnapshot<Json> d) {
  final m = d.data()!;
  return CardAcct(d.id, m['name'] as String, (m['closingDay'] as num).toInt(), (m['limit'] as num).toDouble());
}

/// Icons can't be stored, so a goal keeps the position of its icon in [goalIcons].
Json goalToMap(Goal g, int order) => {
  'name': g.name,
  'target': g.target,
  'base': g.base,
  'icon': goalIcons.indexOf(g.icon).clamp(0, goalIcons.length - 1),
  'due': g.due == null ? null : Timestamp.fromDate(g.due!),
  'label': g.label,
  'order': order,
};

Goal goalFromDoc(DocumentSnapshot<Json> d) {
  final m = d.data()!;
  final i = (m['icon'] as num?)?.toInt() ?? 0;
  return Goal(
    d.id,
    m['name'] as String,
    (m['target'] as num).toDouble(),
    (m['base'] as num?)?.toDouble() ?? 0,
    goalIcons[i.clamp(0, goalIcons.length - 1)],
    due: (m['due'] as Timestamp?)?.toDate(),
    label: m['label'] as String?,
  );
}
