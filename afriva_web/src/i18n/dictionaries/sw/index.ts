import type { Dictionary } from "../en";
import admin from "./admin";
import common from "./common";
import creator from "./creator";
import errors from "./errors";
import portal from "./portal";
import site from "./site";
import studio from "./studio";
import user from "./user";

const dict: Dictionary = { common, errors, site, user, portal, admin, studio, creator };

export default dict;
