import { Spinner } from "../ui/Feedback";
import { LogoMark } from "../ui/Logo";

export function PortalFallback() {
  return (
    <div className="grid min-h-dvh flex-1 place-items-center">
      <div className="flex flex-col items-center gap-4 text-text-muted">
        <LogoMark size={40} />
        <Spinner />
      </div>
    </div>
  );
}
