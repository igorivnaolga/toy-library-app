import "package:flutter/material.dart";
import "../../core/app_input_field.dart";
import "../../core/app_text_styles.dart";
import "../../core/app_theme.dart";
import "../../core/brand_chip_button.dart";
import "../info/library_info_copy.dart";
import "../profile/kid_profile.dart";
import "registration_form_data.dart";
import "registration_heard_about_field.dart";
import "registration_password_screen.dart";
import "registration_validated_field.dart";
import "registration_validation.dart";

/// Multi-step digital version of the Church Corner Toy Library paper form.
class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _form = RegistrationFormData();
  final _pageController = PageController();
  int _step = 0;

  late final TextEditingController _parentA;
  late final TextEditingController _parentB;
  late final TextEditingController _address1;
  late final TextEditingController _address2;
  late final TextEditingController _suburb;
  late final TextEditingController _mobilePhone;
  late final TextEditingController _email;
  late final TextEditingController _altName;
  late final TextEditingController _altAddress;
  late final TextEditingController _altPhone;
  late final TextEditingController _heardAboutOther;
  late final TextEditingController _skills;
  String? _heardAboutSource;
  late final TextEditingController _kidName;

  DateTime? _kidBirthDate;
  int _kidFieldGeneration = 0;

  final _parentAFieldKey = GlobalKey<RegistrationValidatedFieldState>();
  final _parentBFieldKey = GlobalKey<RegistrationValidatedFieldState>();
  final _address1FieldKey = GlobalKey<RegistrationValidatedFieldState>();
  final _address2FieldKey = GlobalKey<RegistrationValidatedFieldState>();
  final _suburbFieldKey = GlobalKey<RegistrationValidatedFieldState>();
  final _mobileFieldKey = GlobalKey<RegistrationValidatedFieldState>();
  final _emailFieldKey = GlobalKey<RegistrationValidatedFieldState>();
  final _altNameFieldKey = GlobalKey<RegistrationValidatedFieldState>();
  final _altAddressFieldKey = GlobalKey<RegistrationValidatedFieldState>();
  final _altPhoneFieldKey = GlobalKey<RegistrationValidatedFieldState>();
  final _heardAboutFieldKey = GlobalKey<RegistrationHeardAboutFieldState>();
  final _skillsFieldKey = GlobalKey<RegistrationValidatedFieldState>();

  @override
  void initState() {
    super.initState();
    _parentA = TextEditingController();
    _parentB = TextEditingController();
    _address1 = TextEditingController();
    _address2 = TextEditingController();
    _suburb = TextEditingController();
    _mobilePhone = TextEditingController();
    _email = TextEditingController();
    _altName = TextEditingController();
    _altAddress = TextEditingController();
    _altPhone = TextEditingController();
    _heardAboutOther = TextEditingController();
    _skills = TextEditingController();
    _kidName = TextEditingController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _parentA.dispose();
    _parentB.dispose();
    _address1.dispose();
    _address2.dispose();
    _suburb.dispose();
    _mobilePhone.dispose();
    _email.dispose();
    _altName.dispose();
    _altAddress.dispose();
    _altPhone.dispose();
    _heardAboutOther.dispose();
    _skills.dispose();
    _kidName.dispose();
    super.dispose();
  }

  void _syncFormFromControllers() {
    _form.parentAName = _parentA.text;
    _form.parentBName = _parentB.text;
    _form.addressLine1 = _address1.text;
    _form.addressLine2 = _address2.text;
    _form.suburb = _suburb.text;
    _form.mobilePhone = _mobilePhone.text;
    _form.email = _email.text;
    _form.altContactName = _altName.text;
    _form.altContactAddress = _altAddress.text;
    _form.altContactPhone = _altPhone.text;
    _form.heardAboutUs = resolveHeardAboutUs(
      source: _heardAboutSource,
      otherText: _heardAboutOther.text,
    );
    _form.skills = _skills.text;
  }

  String? _validateStep(int step) {
    _syncFormFromControllers();
    switch (step) {
      case 0:
        return RegistrationValidation.requiredFullName(
              _form.parentAName,
              label: "Parent A's full name",
            ) ??
            RegistrationValidation.optionalFullName(
              _form.parentBName,
              label: "Parent B's full name",
            ) ??
            RegistrationValidation.requiredAddressLine(_form.addressLine1) ??
            RegistrationValidation.optionalAddressLine(_form.addressLine2) ??
            RegistrationValidation.requiredSuburb(_form.suburb) ??
            RegistrationValidation.requiredNzMobile(_form.mobilePhone) ??
            RegistrationValidation.requiredEmail(_form.email);
      case 1:
        for (final kid in _form.kids) {
          final nameError = RegistrationValidation.requiredPersonName(
            kid.name,
            label: "child's name",
          );
          if (nameError != null) return nameError;
          if (kid.birthDate == null) {
            return "Enter each child's date of birth.";
          }
        }
        return null;
      case 2:
        return RegistrationValidation.requiredFullName(
              _form.altContactName,
              label: "alternative contact full name",
            ) ??
            RegistrationValidation.requiredAddressLine(
              _form.altContactAddress,
            ) ??
            RegistrationValidation.requiredNzPhone(_form.altContactPhone) ??
            RegistrationValidation.heardAboutUs(
              _heardAboutSource,
              _heardAboutOther.text,
            ) ??
            RegistrationValidation.optionalFreeText(_form.skills);
      case 3:
        if (_form.membershipTier == null) {
          return "Choose a membership type.";
        }
        return null;
      case 4:
        if (!_form.termsAccepted || !_form.liabilityAccepted) {
          return "Accept the membership terms and liability waiver.";
        }
        if (_form.textRemindersConsent == null) {
          return "Choose whether we may send text reminders.";
        }
        return null;
      default:
        return null;
    }
  }

  List<GlobalKey<RegistrationValidatedFieldState>> _fieldKeysForStep(int step) {
    switch (step) {
      case 0:
        return [
          _parentAFieldKey,
          _parentBFieldKey,
          _address1FieldKey,
          _address2FieldKey,
          _suburbFieldKey,
          _mobileFieldKey,
          _emailFieldKey,
        ];
      case 2:
        return [
          _altNameFieldKey,
          _altAddressFieldKey,
          _altPhoneFieldKey,
          _skillsFieldKey,
        ];
      default:
        return [];
    }
  }

  void _validateFieldsForStep(int step) {
    for (final key in _fieldKeysForStep(step)) {
      key.currentState?.validate(showSnackBar: false);
    }
    if (step == 2) {
      _heardAboutFieldKey.currentState?.validate(showSnackBar: false);
    }
  }

  Future<void> _next() async {
    FocusManager.instance.primaryFocus?.unfocus();
    _syncFormFromControllers();
    _validateFieldsForStep(_step);
    final error = _validateStep(_step);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
      return;
    }
    if (_step == 4) {
      _syncFormFromControllers();
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => RegistrationPasswordScreen(form: _form),
        ),
      );
      return;
    }
    setState(() => _step += 1);
    await _pageController.nextPage(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  Future<void> _back() async {
    if (_step == 0) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _step -= 1);
    await _pageController.previousPage(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  Future<void> _pickKidBirthDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _kidBirthDate ?? DateTime(DateTime.now().year - 5),
      firstDate: DateTime(1990),
      lastDate: DateTime.now(),
      helpText: "Child date of birth",
    );
    if (picked != null) setState(() => _kidBirthDate = picked);
  }

  void _addKid() {
    final nameError = RegistrationValidation.requiredPersonName(
      _kidName.text,
      label: "child's name",
    );
    if (nameError != null || _kidBirthDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            nameError ?? "Enter the child's date of birth.",
          ),
        ),
      );
      return;
    }
    final name = _kidName.text.trim();
    if (_form.kids.length >= 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You can add up to 4 children on the form.")),
      );
      return;
    }
    setState(() {
      _form.kids = [
        ..._form.kids,
        KidProfile(
          name: name,
          birthDate: DateTime(
            _kidBirthDate!.year,
            _kidBirthDate!.month,
            _kidBirthDate!.day,
          ),
        ),
      ];
      _kidName.clear();
      _kidBirthDate = null;
      _kidFieldGeneration += 1;
    });
  }

  void _removeKid(int index) {
    setState(() {
      _form.kids = [
        ..._form.kids.sublist(0, index),
        ..._form.kids.sublist(index + 1),
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    final stepLabels = [
      "Family contact details",
      "Children",
      "Alternative contact",
      "Membership",
      "Agreements",
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Join the toy library"),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                for (var i = 0; i < stepLabels.length; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  Expanded(
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: i <= _step
                            ? kBrandYellow
                            : Theme.of(context)
                                .colorScheme
                                .outlineVariant
                                .withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                stepLabels[_step],
                style: context.screenTitle,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _FamilyStep(
                  parentA: _parentA,
                  parentB: _parentB,
                  address1: _address1,
                  address2: _address2,
                  suburb: _suburb,
                  mobilePhone: _mobilePhone,
                  email: _email,
                  parentAFieldKey: _parentAFieldKey,
                  parentBFieldKey: _parentBFieldKey,
                  address1FieldKey: _address1FieldKey,
                  address2FieldKey: _address2FieldKey,
                  suburbFieldKey: _suburbFieldKey,
                  mobileFieldKey: _mobileFieldKey,
                  emailFieldKey: _emailFieldKey,
                ),
                _ChildrenStep(
                  kids: _form.kids,
                  kidName: _kidName,
                  kidNameFieldKey: ValueKey(_kidFieldGeneration),
                  kidBirthDate: _kidBirthDate,
                  onPickBirthDate: _pickKidBirthDate,
                  onAddKid: _addKid,
                  onRemoveKid: _removeKid,
                  formatBirthDate: _formatBirthDate,
                ),
                _AlternativeContactStep(
                  altName: _altName,
                  altAddress: _altAddress,
                  altPhone: _altPhone,
                  heardAboutSource: _heardAboutSource,
                  heardAboutOther: _heardAboutOther,
                  onHeardAboutSourceChanged: (source) =>
                      setState(() => _heardAboutSource = source),
                  skills: _skills,
                  altNameFieldKey: _altNameFieldKey,
                  altAddressFieldKey: _altAddressFieldKey,
                  altPhoneFieldKey: _altPhoneFieldKey,
                  heardAboutFieldKey: _heardAboutFieldKey,
                  skillsFieldKey: _skillsFieldKey,
                ),
                _MembershipStep(
                  selectedTier: _form.membershipTier,
                  onTierChanged: (tier) =>
                      setState(() => _form.membershipTier = tier),
                ),
                _AgreementsStep(
                  termsAccepted: _form.termsAccepted,
                  liabilityAccepted: _form.liabilityAccepted,
                  textRemindersConsent: _form.textRemindersConsent,
                  onTermsChanged: (value) =>
                      setState(() => _form.termsAccepted = value ?? false),
                  onLiabilityChanged: (value) =>
                      setState(() => _form.liabilityAccepted = value ?? false),
                  onTextConsentChanged: (value) =>
                      setState(() => _form.textRemindersConsent = value),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _back,
                    style: brandOutlinedButtonStyle(),
                    child: Text(_step == 0 ? "Cancel" : "Back"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: BrandChipButton(
                    label: _step == 4 ? "Set password" : "Next",
                    large: true,
                    onPressed: _next,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatBirthDate(DateTime date) {
    const months = [
      "Jan", "Feb", "Mar", "Apr", "May", "Jun",
      "Jul", "Aug", "Sep", "Oct", "Nov", "Dec",
    ];
    return "${date.day} ${months[date.month - 1]} ${date.year}";
  }
}

class _FamilyStep extends StatelessWidget {
  const _FamilyStep({
    required this.parentA,
    required this.parentB,
    required this.address1,
    required this.address2,
    required this.suburb,
    required this.mobilePhone,
    required this.email,
    required this.parentAFieldKey,
    required this.parentBFieldKey,
    required this.address1FieldKey,
    required this.address2FieldKey,
    required this.suburbFieldKey,
    required this.mobileFieldKey,
    required this.emailFieldKey,
  });

  final TextEditingController parentA;
  final TextEditingController parentB;
  final TextEditingController address1;
  final TextEditingController address2;
  final TextEditingController suburb;
  final TextEditingController mobilePhone;
  final TextEditingController email;
  final GlobalKey<RegistrationValidatedFieldState> parentAFieldKey;
  final GlobalKey<RegistrationValidatedFieldState> parentBFieldKey;
  final GlobalKey<RegistrationValidatedFieldState> address1FieldKey;
  final GlobalKey<RegistrationValidatedFieldState> address2FieldKey;
  final GlobalKey<RegistrationValidatedFieldState> suburbFieldKey;
  final GlobalKey<RegistrationValidatedFieldState> mobileFieldKey;
  final GlobalKey<RegistrationValidatedFieldState> emailFieldKey;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: kGroupHeaderBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: kGroupHeaderBorder),
          ),
          child: Text(
            "${LibraryInfoCopy.libraryName}\n"
            "${LibraryInfoCopy.locationAddressLine2}\n\n"
            "Please bring proof of address next time you visit the toy library.",
            style: context.listSubtitle,
          ),
        ),
        const SizedBox(height: 16),
        RegistrationValidatedField(
          key: parentAFieldKey,
          controller: parentA,
          label: "Parent A's full name",
          textCapitalization: TextCapitalization.words,
          validator: (value) => RegistrationValidation.requiredFullName(
            value,
            label: "Parent A's full name",
          ),
        ),
        const SizedBox(height: 12),
        RegistrationValidatedField(
          key: parentBFieldKey,
          controller: parentB,
          label: "Parent B's full name",
          optional: true,
          textCapitalization: TextCapitalization.words,
          validator: (value) => RegistrationValidation.optionalFullName(
            value,
            label: "Parent B's full name",
          ),
        ),
        const SizedBox(height: 12),
        RegistrationValidatedField(
          key: address1FieldKey,
          controller: address1,
          label: "Address line 1",
          textCapitalization: TextCapitalization.words,
          validator: RegistrationValidation.requiredAddressLine,
        ),
        const SizedBox(height: 12),
        RegistrationValidatedField(
          key: address2FieldKey,
          controller: address2,
          label: "Address line 2",
          optional: true,
          textCapitalization: TextCapitalization.words,
          validator: RegistrationValidation.optionalAddressLine,
        ),
        const SizedBox(height: 12),
        RegistrationValidatedField(
          key: suburbFieldKey,
          controller: suburb,
          label: "Suburb",
          textCapitalization: TextCapitalization.words,
          validator: RegistrationValidation.requiredSuburb,
        ),
        const SizedBox(height: 12),
        RegistrationValidatedField(
          key: mobileFieldKey,
          controller: mobilePhone,
          label: "Mobile phone",
          keyboardType: TextInputType.phone,
          validator: RegistrationValidation.requiredNzMobile,
        ),
        const SizedBox(height: 12),
        RegistrationValidatedField(
          key: emailFieldKey,
          controller: email,
          label: "Email",
          keyboardType: TextInputType.emailAddress,
          textCapitalization: TextCapitalization.none,
          validator: RegistrationValidation.requiredEmail,
        ),
      ],
    );
  }
}

class _ChildrenStep extends StatelessWidget {
  const _ChildrenStep({
    required this.kids,
    required this.kidName,
    required this.kidNameFieldKey,
    required this.kidBirthDate,
    required this.onPickBirthDate,
    required this.onAddKid,
    required this.onRemoveKid,
    required this.formatBirthDate,
  });

  final List<KidProfile> kids;
  final TextEditingController kidName;
  final Key kidNameFieldKey;
  final DateTime? kidBirthDate;
  final VoidCallback onPickBirthDate;
  final VoidCallback onAddKid;
  final ValueChanged<int> onRemoveKid;
  final String Function(DateTime date) formatBirthDate;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        Text(
          "Children who will borrow toys",
          style: context.listSubtitle,
        ),
        const SizedBox(height: 12),
        if (kids.isEmpty)
          Text(
            "No children added yet. You can add them now or continue and "
            "update your profile later.",
            style: context.profileSecondary,
          ),
        for (var i = 0; i < kids.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(kids[i].name, style: context.cardTitle),
            subtitle: kids[i].birthDate == null
                ? null
                : Text(formatBirthDate(kids[i].birthDate!)),
            trailing: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => onRemoveKid(i),
            ),
          ),
        ],
        const SizedBox(height: 16),
        RegistrationValidatedField(
          key: kidNameFieldKey,
          controller: kidName,
          label: "Child's name",
          optional: true,
          textCapitalization: TextCapitalization.words,
          validator: (value) => RegistrationValidation.requiredPersonName(
            value,
            label: "child's name",
          ),
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: onPickBirthDate,
          borderRadius: BorderRadius.circular(12),
          child: InputDecorator(
            decoration: labeledInputDecoration(
              context,
              labelText: "Date of birth",
            ),
            child: Text(
              kidBirthDate == null
                  ? "Select date"
                  : formatBirthDate(kidBirthDate!),
              style: kidBirthDate == null
                  ? fieldPlaceholderStyle(context)
                  : fieldTextStyle(context),
            ),
          ),
        ),
        const SizedBox(height: 12),
        BrandChipButton(
          label: "Add child",
          onPressed: onAddKid,
        ),
      ],
    );
  }
}

class _AlternativeContactStep extends StatelessWidget {
  const _AlternativeContactStep({
    required this.altName,
    required this.altAddress,
    required this.altPhone,
    required this.heardAboutSource,
    required this.heardAboutOther,
    required this.onHeardAboutSourceChanged,
    required this.skills,
    required this.altNameFieldKey,
    required this.altAddressFieldKey,
    required this.altPhoneFieldKey,
    required this.heardAboutFieldKey,
    required this.skillsFieldKey,
  });

  final TextEditingController altName;
  final TextEditingController altAddress;
  final TextEditingController altPhone;
  final String? heardAboutSource;
  final TextEditingController heardAboutOther;
  final ValueChanged<String?> onHeardAboutSourceChanged;
  final TextEditingController skills;
  final GlobalKey<RegistrationValidatedFieldState> altNameFieldKey;
  final GlobalKey<RegistrationValidatedFieldState> altAddressFieldKey;
  final GlobalKey<RegistrationValidatedFieldState> altPhoneFieldKey;
  final GlobalKey<RegistrationHeardAboutFieldState> heardAboutFieldKey;
  final GlobalKey<RegistrationValidatedFieldState> skillsFieldKey;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        Text(
          "Alternative contact person not at your address",
          style: context.listSubtitle,
        ),
        const SizedBox(height: 12),
        RegistrationValidatedField(
          key: altNameFieldKey,
          controller: altName,
          label: "Full name",
          textCapitalization: TextCapitalization.words,
          validator: (value) => RegistrationValidation.requiredFullName(
            value,
            label: "alternative contact full name",
          ),
        ),
        const SizedBox(height: 12),
        RegistrationValidatedField(
          key: altAddressFieldKey,
          controller: altAddress,
          label: "Address",
          maxLines: 2,
          textCapitalization: TextCapitalization.words,
          validator: RegistrationValidation.requiredAddressLine,
        ),
        const SizedBox(height: 12),
        RegistrationValidatedField(
          key: altPhoneFieldKey,
          controller: altPhone,
          label: "Phone",
          keyboardType: TextInputType.phone,
          validator: RegistrationValidation.requiredNzPhone,
        ),
        const SizedBox(height: 20),
        RegistrationHeardAboutField(
          key: heardAboutFieldKey,
          selectedSource: heardAboutSource,
          otherController: heardAboutOther,
          onSourceChanged: onHeardAboutSourceChanged,
        ),
        const SizedBox(height: 12),
        RegistrationValidatedField(
          key: skillsFieldKey,
          controller: skills,
          label: "What skills do you have that could help us?",
          optional: true,
          maxLines: 2,
          validator: RegistrationValidation.optionalFreeText,
        ),
      ],
    );
  }
}

class _MembershipStep extends StatelessWidget {
  const _MembershipStep({
    required this.selectedTier,
    required this.onTierChanged,
  });

  final String? selectedTier;
  final ValueChanged<String> onTierChanged;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        Text(
          "Choose your membership / payment type",
          style: context.listSubtitle,
        ),
        const SizedBox(height: 12),
        _tierTile(
          context,
          value: "duty",
          title: "Duty membership",
          subtitle: LibraryInfoCopy.dutyMembershipDescription,
        ),
        _tierTile(
          context,
          value: "non_duty",
          title: "Non-duty membership",
          subtitle: LibraryInfoCopy.nonDutyMembershipDescription,
        ),
        _tierTile(
          context,
          value: "casual",
          title: "Casual membership",
          subtitle: LibraryInfoCopy.casualMembershipDescription,
        ),
      ],
    );
  }

  Widget _tierTile(
    BuildContext context, {
    required String value,
    required String title,
    required String subtitle,
  }) {
    return RadioListTile<String>(
      value: value,
      groupValue: selectedTier,
      onChanged: (tier) {
        if (tier != null) onTierChanged(tier);
      },
      title: Text(title, style: context.cardTitle.copyWith(fontSize: 15)),
      subtitle: Text(
        subtitle,
        style: context.listSubtitle,
      ),
      isThreeLine: true,
      contentPadding: EdgeInsets.zero,
    );
  }

}

class _AgreementsStep extends StatelessWidget {
  const _AgreementsStep({
    required this.termsAccepted,
    required this.liabilityAccepted,
    required this.textRemindersConsent,
    required this.onTermsChanged,
    required this.onLiabilityChanged,
    required this.onTextConsentChanged,
  });

  final bool termsAccepted;
  final bool liabilityAccepted;
  final bool? textRemindersConsent;
  final ValueChanged<bool?> onTermsChanged;
  final ValueChanged<bool?> onLiabilityChanged;
  final ValueChanged<bool?> onTextConsentChanged;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        Text("Conditions of membership", style: context.formSectionLabel),
        const SizedBox(height: 8),
        Text(
          "I apply on behalf of my family to join the Church Corner Toy "
          "Library and agree to:\n"
          "• Pay for damage to borrowed items\n"
          "• Return items clean and hygienic\n"
          "• Pay late-return charges\n"
          "• Return items within two weeks or inform the library\n"
          "• Follow the loan structure in the membership rules\n"
          "• Understand borrowing privileges may be revoked for repeat "
          "offences, and replacement charges of up to \$200 may apply",
          style: context.listSubtitle,
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: termsAccepted,
          onChanged: onTermsChanged,
          title: const Text("I agree to the conditions of membership"),
          controlAffinity: ListTileControlAffinity.leading,
        ),
        const SizedBox(height: 8),
        Text("Liability waiver", style: context.formSectionLabel),
        const SizedBox(height: 8),
        Text(
          "I release the Church Corner Toy Library from liability for "
          "accidents or harm arising from borrowed items, and agree to "
          "indemnify the library against related claims.",
          style: context.listSubtitle,
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: liabilityAccepted,
          onChanged: onLiabilityChanged,
          title: const Text("I accept the liability waiver and indemnity"),
          controlAffinity: ListTileControlAffinity.leading,
        ),
        const SizedBox(height: 12),
        Text(
          "Do you consent to text reminders for overdue toys or upcoming "
          "volunteer duties?",
          style: context.listSubtitle,
        ),
        RadioListTile<bool>(
          value: true,
          groupValue: textRemindersConsent,
          onChanged: onTextConsentChanged,
          title: const Text("Yes"),
          contentPadding: EdgeInsets.zero,
        ),
        RadioListTile<bool>(
          value: false,
          groupValue: textRemindersConsent,
          onChanged: onTextConsentChanged,
          title: const Text("No"),
          contentPadding: EdgeInsets.zero,
        ),
      ],
    );
  }
}
