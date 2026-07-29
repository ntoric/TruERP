export namespace main {
	
	export class PrinterInfo {
	    name: string;
	    is_default: boolean;
	
	    static createFrom(source: any = {}) {
	        return new PrinterInfo(source);
	    }
	
	    constructor(source: any = {}) {
	        if ('string' === typeof source) source = JSON.parse(source);
	        this.name = source["name"];
	        this.is_default = source["is_default"];
	    }
	}

}

