class UserModel {

  final int id;
  final String name;
  final String email;
  final int roleId;
  final String token;

  UserModel({

    required this.id,
    required this.name,
    required this.email,
    required this.roleId,
    required this.token,

  });

  factory UserModel.fromJson(Map<String,dynamic> json){

    return UserModel(

      id: json["user"]["id"],

      name: json["user"]["name"],

      email: json["user"]["email"],

      roleId: json["user"]["role"],

      token: json["token"],

    );

  }

}